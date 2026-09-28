require "digest"
require "json"

# Export the pinned CE process snapshots without reading native output. Object
# offsets correspond to the executable hash enforced by the shell wrapper.

plan_path, snapshot_root, level_root, output_path = ARGV
abort "usage: export.rb PLAN SNAPSHOTS LEVELS OUTPUT" unless output_path

ACTION_NAMES = [
  nil, "walking", "ascending", "digging", "climbing", "drowning", "hoisting",
  "building", "bashing", "mining", "falling", "floating", "splatting",
  "exiting", "vaporizing", "blocking", "shrugging", "ohNo", "exploding",
  "walking", "platforming", "stacking", "stoning", "stoneFinish", "swimming",
  "gliding", "disarming", nil, "fencing", "reaching", "shimmying", "jumping",
  "dehoisting", "sliding", "lasering", nil
].freeze
SKILLS = [
  ["walker", 19], ["jumper", 31], ["shimmier", 30], ["slider", 33],
  ["climber", 4], ["swimmer", 24], ["floater", 11], ["glider", 25],
  ["disarmer", 26], ["bomber", 18], ["stoner", 22], ["blocker", 15],
  ["platformer", 20], ["builder", 7], ["stacker", 21], ["laserer", 34],
  ["basher", 8], ["fencer", 28], ["miner", 9], ["digger", 3], ["cloner", 27]
].freeze
ZONE_EFFECTS = [1, 2, 3, 4, 5, 6, 11, 12, 14, 15, 17, 20, 21, 24, 26, 27,
                31, 35, 36, 37, 38, 39, 40].freeze
ANIMATED_EFFECTS = [4, 11, 12, 15, 17, 24, 31, 35].freeze

def uint32(bytes, offset)
  bytes.byteslice(offset, 4).unpack1("V")
end

def int32(bytes, offset)
  value = uint32(bytes, offset)
  value >= 0x80000000 ? value - 0x100000000 : value
end

def masks(physics)
  solid = []
  steel = []
  one_way = []
  physics.each do |pixel|
    solid << (pixel & 1 == 0 ? 0 : 1)
    steel << (pixel & 2 == 0 ? 0 : 1)
    one_way << if pixel & 4 == 0
                 0
               elsif pixel & 8 != 0
                 1
               elsif pixel & 16 != 0
                 2
               elsif pixel & 64 != 0
                 3
               elsif pixel & 32 != 0
                 4
               else
                 abort "one-way pixel has no direction"
               end
  end
  [solid.pack("C*"), steel.pack("C*"), one_way.pack("C*")]
end

def brick_palette(renderer)
  palette = renderer.byteslice(0x211c, 48)&.unpack("V*")
  abort "brick palette is missing" unless palette&.length == 12 && palette.uniq.length > 4
  palette
end

levels = {}
Dir.glob(File.join(level_root, "**", "*.nxlv")).sort.each do |path|
  text = File.read(path, encoding: "bom|utf-8")
  id = text[/^\s*ID\s+(?:x)?([0-9a-f]{16})\s*$/i, 1]
  next unless id
  version = text[/^\s*VERSION\s+(?:x)?([0-9a-f]{16})\s*$/i, 1] || "0"
  # TIME_LIMIT is also a valid field inside preplaced-lemming sections. Only
  # the level header controls the game clock.
  header = text.split(/^\s*\$/).first
  has_time_limit = header.match?(/^\s*TIME_LIMIT\s+\d+\s*$/i)
  key = id.downcase
  abort "duplicate level ID x#{id.upcase} below #{level_root}" if levels.key?(key)
  levels[key] = ["x#{id.upcase}", format("x%016X", version.to_i(16)), has_time_limit]
end

records = []
File.foreach(plan_path) do |line|
  replay_hash, requested_tick, replay_path = line.chomp.split("\t", 3)
  directory = File.join(snapshot_root, replay_hash)
  required_files = %w[game.bin lemmings.bin metadata.txt physics.bin initial-physics.bin
                      terrain.bin initial-terrain.bin renderer.bin gadgets.bin]
  next unless required_files.all? { |name| File.exist?(File.join(directory, name)) }
  replay_text = File.read(replay_path, encoding: "bom|utf-8")
  replay_id = replay_text[/^ID\s+(?:x)?([0-9a-f]{16})\s*$/i, 1]
  abort "missing replay ID #{replay_path}" unless replay_id && levels[replay_id.downcase]
  abort "replay hash changed #{replay_path}" unless Digest::SHA256.file(replay_path).hexdigest == replay_hash

  game = File.binread(File.join(directory, "game.bin"))
  lemming_bytes = File.binread(File.join(directory, "lemmings.bin"))
  metadata = File.read(File.join(directory, "metadata.txt")).lines.to_h do |entry|
    key, value = entry.strip.split("=", 2)
    [key, Integer(value)]
  end
  count = metadata.fetch("lemmings")
  abort "bad lemming snapshot #{replay_hash}" unless lemming_bytes.bytesize == count * 0xe4
  lemmings = count.times.map do |index|
    bytes = lemming_bytes.byteslice(index * 0xe4, 0xe4)
    id = int32(bytes, 0x14)
    action_number = bytes.getbyte(0x58)
    action = ACTION_NAMES[action_number]
    abort "unsupported CE action #{action_number}" unless action
    removed = bytes.getbyte(0x59) != 0
    traits = []
    traits << "slider" if bytes.getbyte(0x5d) != 0
    traits << "climber" if bytes.getbyte(0x5e) != 0
    traits << "swimmer" if bytes.getbyte(0x5f) != 0
    traits << "floater" if bytes.getbyte(0x60) != 0
    traits << "glider" if bytes.getbyte(0x61) != 0
    traits << "disarmer" if bytes.getbyte(0x62) != 0
    traits << "zombie" if bytes.getbyte(0x63) != 0
    traits << "neutral" if bytes.getbyte(0x64) != 0
    traits << "blocker" if bytes.getbyte(0x6c) != 0
    value = {
      "id" => id,
      "x" => int32(bytes, 0x1c),
      "y" => int32(bytes, 0x20),
      "direction" => int32(bytes, 0x24),
      "action" => removed ? "removed" : action,
      # CE can expose the end-of-cycle Walker sentinel (frame 8) between its
      # animation increment and wrap. Canonical states store the visible frame.
      "animationFrame" => removed ? 0 : (action == "walking" ? int32(bytes, 0x3c) % 8 : int32(bytes, 0x3c)),
      "actionProgress" => !removed && action == "ascending" ? int32(bytes, 0x28) : 0,
      "fallDistance" => int32(bytes, 0x2c),
      "trueFallDistance" => int32(bytes, 0x30),
      "traits" => traits.sort,
      "bricksRemaining" => int32(bytes, 0x54),
      "isStartingAction" => bytes.getbyte(0x6d) != 0,
      "hasBeenOhNo" => bytes.getbyte(0x65) != 0
    }
    if removed
      # CE stores the aggregate removal mode only in game counters. Immediate
      # traps remove a lemming without changing its current action, while a
      # lemming leaving the bottom retains its falling-family action. The
      # terminal action therefore provides the source-exact distinction that
      # the final-state schema requires.
      value["removalReason"] = case action_number
                               when 13 then "saved"
                               when 18 then "exploded"
                               when 12 then "splatted"
                               when 10, 11, 25 then "fellOut"
                               when 5 then "drowned"
                               when 14 then "trapped"
                               else "trapped"
                               end
    end
    value
  end.sort_by { |lemming| lemming["id"] }

  active_skills = game.byteslice(0x4fd, 10).bytes.take_while { |button| button != 21 }
  skills = active_skills.map do |button|
    name, action_index = SKILLS.fetch(button)
    count_value = int32(game, 0x378 + action_index * 4)
    {"name" => name, "count" => count_value < 0 ? nil : count_value}
  end.sort_by { |skill| skill["name"] }

  physics = File.binread(File.join(directory, "physics.bin")).unpack("V*")
  initial_physics = File.binread(File.join(directory, "initial-physics.bin")).unpack("V*")
  terrain_pixels = File.binread(File.join(directory, "terrain.bin")).unpack("V*")
  initial_terrain = File.binread(File.join(directory, "initial-terrain.bin")).unpack("V*")
  expected_pixels = metadata.fetch("width") * metadata.fetch("height")
  abort "bad terrain snapshot #{replay_hash}" unless [physics, initial_physics, terrain_pixels, initial_terrain].all? { |item| item.length == expected_pixels }
  solid, steel, one_way = masks(physics)
  visual = terrain_pixels.map { |pixel| pixel >> 24 == 0 ? 0 : 1 }.pack("C*")
  palette = brick_palette(File.binread(File.join(directory, "renderer.bin")))
  construction_values = physics.each_index.map do |index|
    shade = palette.index(terrain_pixels[index])
    if physics[index] & 1 != 0 && shade &&
       (physics[index] != initial_physics[index] || terrain_pixels[index] != initial_terrain[index])
      shade + 1
    else
      0
    end
  end
  # CE's gradient clamps each RGB channel independently. Bright MASK colours
  # can therefore make logical steps 10 and 11 the same rendered colour. Recover
  # the last step from CE's Builder/Platformer/Stacker placement geometry rather
  # than consulting the native provenance mask.
  if palette[10] == palette[11]
    relabel = {}
    [[2, -1], [-2, -1], [2, 0], [-2, 0], [0, -1]].each do |dx, dy|
      step_10 = {}
      step_11 = {}
      construction_values.each_index do |index|
        next unless construction_values[index] == 10
        x = index % metadata.fetch("width")
        y = index / metadata.fetch("width")
        x10 = x + dx
        y10 = y + dy
        x11 = x + 2 * dx
        y11 = y + 2 * dy
        next unless x11.between?(0, metadata.fetch("width") - 1) &&
                    y11.between?(0, metadata.fetch("height") - 1)
        index10 = y10 * metadata.fetch("width") + x10
        index11 = y11 * metadata.fetch("width") + x11
        next unless construction_values[index10] == 11 && construction_values[index11] == 11
        step_10[index10] = true
        step_11[index11] = true
      end
      step_11.each_key { |index| relabel[index] = true unless step_10[index] }
    end
    relabel.each_key { |index| construction_values[index] = 12 }
  end
  construction = construction_values.pack("C*")

  gadget_data = File.binread(File.join(directory, "gadgets.bin"))
  gadget_count = uint32(gadget_data, 0)
  gadget_offset = 4
  zone_id = 0
  gadget_frames = []
  gadget_count.times do
    size = uint32(gadget_data, gadget_offset)
    gadget_offset += 4
    gadget = gadget_data.byteslice(gadget_offset, size)
    gadget_offset += size
    effect = int32(gadget, 0x2c)
    next unless ZONE_EFFECTS.include?(effect)
    gadget_frames << {"id" => zone_id, "value" => 0} if ANIMATED_EFFECTS.include?(effect)
    zone_id += 1
  end

  remaining_to_release = int32(game, 0xe8)
  active = int32(game, 0xf0)
  saved = int32(game, 0xf8)
  removed = int32(game, 0xfc)
  active_from_lemmings = lemmings.count { |lemming| lemming["action"] != "removed" }
  saved_from_lemmings = lemmings.count { |lemming| lemming["removalReason"] == "saved" }
  removed_from_lemmings = lemmings.length - active_from_lemmings
  abort "unsettled CE lemming counters #{replay_hash}" unless
    active == active_from_lemmings && saved == saved_from_lemmings && removed == removed_from_lemmings
  complete = remaining_to_release == 0 && active == 0
  time_seconds = int32(game, 0x114)
  state = {
    "format" => "neolemmix-final-state-v1",
    "tick" => int32(game, 0xd8),
    "released" => int32(game, 0x4d8) - remaining_to_release,
    "saved" => saved,
    "lost" => removed - saved,
    "cloned" => int32(game, 0xec),
    "spawnInterval" => int32(game, 0x374),
    "entrancesAreOpen" => game.getbyte(0x119) != 0,
    "isNuking" => game.getbyte(0x498) != 0,
    "isComplete" => complete,
    "didWin" => complete && saved >= int32(game, 0x4dc),
    "skills" => skills,
    "lemmings" => lemmings,
    "disabledZoneIDs" => [],
    "splitterDirections" => [],
    "remainingZoneLemmingCounts" => [],
    "gadgetAnimationFrames" => gadget_frames,
    "secondaryAnimations" => [],
    "terrain" => {
      "width" => metadata.fetch("width"),
      "height" => metadata.fetch("height"),
      "solidSHA256" => Digest::SHA256.hexdigest(solid),
      "steelSHA256" => Digest::SHA256.hexdigest(steel),
      "oneWaySHA256" => Digest::SHA256.hexdigest(one_way),
      "visualOpaqueSHA256" => Digest::SHA256.hexdigest(visual)
    }
  }
  state["remainingTimeTicks"] = time_seconds * 17 - int32(game, 0xe0) if levels.fetch(replay_id.downcase)[2]
  state["terrain"]["constructionShadeSHA256"] = Digest::SHA256.hexdigest(construction) if construction.bytes.any? { |value| value != 0 }
  level_id, level_version, = levels.fetch(replay_id.downcase)
  records << {
    "replaySHA256" => replay_hash,
    "levelID" => level_id,
    "levelVersion" => level_version,
    "state" => state
  }
  abort "snapshot tick differs from plan #{replay_hash}" unless state["tick"] == Integer(requested_tick)
end

manifest = {
  "format" => "neolemmix-final-state-v1",
  "producer" => "ce:NeoLemmixCE-1.2.0-live-memory-export",
  "records" => records.sort_by { |record| record["replaySHA256"] }
}
File.write(output_path, JSON.pretty_generate(manifest) + "\n")
