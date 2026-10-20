import Foundation

/// Wall-clock animation continues while game logic is paused or runs faster.
public struct NuclearExplosionTimeline: Sendable {
  public init() {}
  public static let duration: TimeInterval = 1.8
  public static let maximumBursts = 8
  public struct Burst: Sendable {
    public let centre: SIMD2<Float>
    public let bornAt: TimeInterval
    public let exposure: Bool
    public let worldAnchored: Bool
  }
  public private(set) var bursts: [Burst] = []
  private var lastExposure: TimeInterval = -.infinity

  public mutating func trigger(centres: [SIMD2<Float>], now: TimeInterval, worldAnchored: Bool = false) {
    expire(now: now)
    for centre in centres where centre.x.isFinite && centre.y.isFinite
      && (worldAnchored || ((0...1).contains(centre.x) && (0...1).contains(centre.y))) {
      let exposure = now - lastExposure >= 0.9
      if exposure { lastExposure = now }
      // Keep the main exposure alive when many lemmings detonate together.
      if bursts.count == Self.maximumBursts {
        bursts.remove(at: bursts.firstIndex(where: { !$0.exposure }) ?? 0)
      }
      bursts.append(Burst(centre: centre, bornAt: now, exposure: exposure, worldAnchored: worldAnchored))
    }
  }

  public mutating func expire(now: TimeInterval) {
    bursts.removeAll { now - $0.bornAt >= Self.duration || now < $0.bornAt }
  }

  public mutating func clear() { bursts.removeAll(); lastExposure = -.infinity }

  public func samples(now: TimeInterval, project: (SIMD2<Float>) -> SIMD2<Float>? = { $0 }) -> [SIMD4<Float>] {
    bursts.filter { now >= $0.bornAt && now - $0.bornAt < Self.duration }.compactMap {
      guard let centre = $0.worldAnchored ? project($0.centre) : $0.centre else { return nil }
      return SIMD4(centre.x, centre.y, Float(now - $0.bornAt), $0.exposure ? 1 : 0)
    }
  }
}

/// Matches the Metal uniform layout. Burst samples use a separate buffer.
public struct NuclearExplosionUniforms: Sendable {
  public init(size: SIMD2<Float>, headroom: Float, count: UInt32) {
    self.size = size; self.headroom = headroom; self.count = count
  }
  public var size: SIMD2<Float>
  public var headroom: Float
  public var count: UInt32
}

/// Tier changes blend without restarting the engagement burst.
public struct SuperSpeedTimeline: Sendable {
  public init() {}
  public private(set) var enabled = false
  private var startedAt: TimeInterval = 0
  private var changedAt: TimeInterval = 0
  private var transitionFrom: Float = 0
  public private(set) var multiplier: Double = 3
  private var targetStrength: Float = 0

  public mutating func setEnabled(_ enabled: Bool, now: TimeInterval, immediate: Bool = false, multiplier: Double = 3) {
    let multiplier = min(10, max(1, multiplier))
    if immediate && !enabled { self = Self(); return }
    guard enabled != self.enabled || multiplier != self.multiplier else { return }
    let engaging = enabled && !self.enabled
    let currentIntensity = intensity(now: now)
    self.multiplier = multiplier
    targetStrength = enabled ? Float(min(1.5, sqrt(max(0, multiplier - 1) / 2))) : 0
    transitionFrom = currentIntensity
    changedAt = now
    if engaging { startedAt = now }
    self.enabled = enabled
  }

  public func intensity(now: TimeInterval) -> Float {
    let progress = Float(min(1,max(0,(now-changedAt)/0.2)))
    let eased = progress*progress*(3-2*progress)
    return transitionFrom + (targetStrength-transitionFrom)*eased
  }

  public func isAnimating(now: TimeInterval) -> Bool { enabled || intensity(now: now) > 0 }

  public func sample(now: TimeInterval, headroom: Float) -> SIMD4<Float> {
    let age = Float(max(0,now-startedAt))
    let engagement = enabled ? max(0,1-age/0.65) : 0
    return SIMD4(age,intensity(now: now),engagement,headroom)
  }
}

public struct SuperSpeedUniforms: Sendable {
  public init(field: SIMD4<Float>, animation: SIMD4<Float>, size: SIMD2<Float>, motion: SIMD4<Float> = SIMD4(0, 3, 0, 0)) {
    self.field = field; self.animation = animation; self.size = size; self.motion = motion
  }
  public var field: SIMD4<Float>
  public var animation: SIMD4<Float>
  public var size: SIMD2<Float>
  public var padding = SIMD2<Float>.zero
  public var motion = SIMD4<Float>(0, 3, 0, 0)
}


public enum GameplayHDRShaders {
  public static let source = """
  #include <metal_stdlib>
  using namespace metal;
  struct Vertex { float4 position [[position]]; float2 uv; };
  vertex Vertex flash_vertex(uint id [[vertex_id]]) {
    float2 p[4] = {float2(-1,-1),float2(1,-1),float2(-1,1),float2(1,1)};
    return {float4(p[id],0,1),float2(p[id].x*.5+.5,.5-p[id].y*.5)};
  }
  fragment float4 flash_fragment(Vertex v [[stage_in]], texture2d<float> mask [[texture(0)]],
                                  constant float &headroom [[buffer(0)]]) {
    constexpr sampler s(filter::nearest,address::clamp_to_zero);
    float2 pulse = mask.sample(s,v.uv).rg;
    float strength = pulse.r;
    if (pulse.g > 0 && headroom > 1) return float4(float3(.18,1,.18) * (1 + (headroom-1)*pulse.g),1);
    if (strength <= 0 || headroom <= 1) return float4(0);
    if (strength <= .25) {
      float alpha = strength;
      return float4(float3(1,.91,.65) * headroom * alpha, alpha);
    }
    float3 tint = strength > .75 ? float3(1) : float3(1,1,0);
    return float4(tint * (1 + (headroom-1)*strength),1);
  }

  struct NuclearUniforms { float2 size; float headroom; uint count; };
  float blast_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
  }
  float blast_noise(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f*f*(3-2*f);
    return mix(mix(blast_hash(i), blast_hash(i+float2(1,0)), f.x),
               mix(blast_hash(i+float2(0,1)), blast_hash(i+1), f.x), f.y);
  }
  float blast_fbm(float2 p) {
    float value = 0, weight = .55;
    for (int i=0; i<4; ++i) {
      value += weight * blast_noise(p);
      p = float2(p.x*.8-p.y*.6,p.x*.6+p.y*.8)*2.07+17.3;
      weight *= .48;
    }
    return value;
  }
  float4 blast_over(float4 front, float4 back) {
    return front + back * (1-front.a);
  }
  fragment float4 nuclear_fragment(Vertex v [[stage_in]],
    constant NuclearUniforms &u [[buffer(0)]], constant float4 *bursts [[buffer(1)]]) {
    float4 result = float4(0);
    float exposure = 0;
    float headroom = clamp(u.headroom, 1.0f, 8.0f);
    float2 aspect = u.size / max(1.0f, min(u.size.x,u.size.y));
    for (uint i=0; i<min(u.count,8u); ++i) {
      float4 burst = bursts[i];
      float t = burst.z;
      if (t < 0 || t >= 1.8) continue;
      float fade = 1-smoothstep(.95f,1.8f,t);
      float2 p = (v.uv-burst.xy)*aspect;
      float d = length(p);
      // The first flash collapses briefly before the fireball blooms again.
      float flash = .94*exp(-t*24) + .78*exp(-pow((t-.16)/.105,2.0f));
      exposure = max(exposure, burst.w*flash);
      float radius = .025 + .135*(1-exp(-t*5));
      float rise = .26*smoothstep(.16f,1.65f,t);
      float2 cloud = p + float2(0,rise);
      float n = .5, detail = .5;
      if (length(cloud) < radius*1.5 || (abs(p.x) < .07 && abs(p.y) < rise+.06)) {
        n = blast_fbm(cloud*38+float2(burst.x*23,-t*1.8));
        detail = blast_fbm(cloud*83+float2(t*1.4,burst.y*31));
      }
      float billow = smoothstep(.3f,1.3f,t);
      float capShape = length(cloud/float2(1+billow*.25,.82-billow*.26));
      float edge = radius*(.80+.37*n);
      float cap = 1-smoothstep(edge-.018,edge+.012,capShape);
      float column = (1-smoothstep(.014f,.048f,abs(p.x)+(n-.5)*.02))
        * smoothstep(-rise-.01f,-rise+.03f,p.y)
        * (1-smoothstep(.005f,.055f,p.y)) * smoothstep(.25f,.75f,t);
      float density = max(cap,column*.85);
      float heat = saturate(1-capShape/max(radius,.001f));
      heat = saturate(heat*.85+n*.65+detail*.18-t*.34);
      float3 fire = mix(float3(.18,.025,.009),float3(1,.16,.008),smoothstep(0.0f,.32f,heat));
      fire = mix(fire,float3(1,.72,.18),smoothstep(.25f,.65f,heat));
      fire = mix(fire,float3(1,.97,.84),smoothstep(.60f,.88f,heat));
      float smoke = smoothstep(.55f,1.5f,t)*(1-smoothstep(.12f,.55f,heat));
      fire = mix(fire,float3(.075,.06,.055)*( .7+n),smoke);
      float peak = 1+(headroom-1)*smoothstep(.4f,.9f,heat)*exp(-t*1.5);
      float alpha = density*fade*.94;
      float4 body = float4(fire*peak*alpha,alpha);

      // Broad scattered light, a thin pressure front and a ground-level dust ring.
      float halo = exp(-d*d/(radius*radius*3.8)) * exp(-t*2.7)*.5;
      float ringRadius = .015 + t*.53;
      float ring = exp(-pow((d-ringRadius)/(.005+t*.010),2.0f))*exp(-t*2.8)
        * smoothstep(.015f,.08f,t);
      float groundDistance = length(p/float2(1,.19));
      float dust = exp(-pow((groundDistance-t*.30)/(.012+t*.016),2.0f))
        * exp(-t*2)*smoothstep(.08f,.24f,t)*( .55+.45*n);
      float streak = exp(-abs(p.y)*350)*exp(-abs(p.x)*3.3)*exp(-t*9)*.65;
      float glowAlpha = saturate((halo+ring*.5+dust*.25+streak)*fade);
      float3 glow = (float3(1,.36,.06)*halo+float3(.8,.9,1)*ring*.5
        +float3(.56,.35,.16)*dust*.25+float3(1,.83,.53)*streak)*fade;
      float4 light = float4(glow*(1+(headroom-1)*exp(-t*6)),glowAlpha);
      result = blast_over(body,blast_over(light,result));
    }
    // Premultiplied output remains visible at SDR headroom, including the margins.
    float3 white = mix(float3(1,.97,.89),float3(1),saturate(exposure));
    result = blast_over(float4(white*headroom*exposure,exposure),result);
    result.a = saturate(result.a);
    result.rgb = clamp(result.rgb,float3(0),float3(headroom*result.a));
    return result;
  }
  struct SpeedUniforms { float4 field; float4 animation; float2 size; float2 padding; float4 motion; };
  fragment float4 speed_fragment(Vertex v [[stage_in]], constant SpeedUniforms &u [[buffer(0)]]) {
    if (u.animation.y <= 0 || any(u.field.zw <= 0)) return float4(0);
    float2 uv = (v.uv*u.size-u.field.xy)/u.field.zw;
    if (any(uv < 0) || any(uv > 1)) return float4(0);
    float2 p = (uv-.5)*u.field.zw/min(u.field.z,u.field.w);
    float r = length(p), t = u.motion.w > .5 ? u.motion.x : u.animation.x;
    float tier = clamp(u.motion.y,2.0f,10.0f);
    float edge = smoothstep(.28f,.92f,max(abs(uv.x-.5),abs(uv.y-.5))*2);
    float angle = atan2(p.y,p.x);
    float lane = (angle+M_PI_F)/(2*M_PI_F)*84;
    float id = floor(lane), seed = blast_hash(float2(id,4.7));
    float across = fract(lane)-(.25+.5*seed);
    float rayCore = exp(-pow(across/(.015+.016*seed),2.0f));
    float softThread = exp(-pow(across/.14,2.0f));
    float travel = fract(r*.8-t*(1.1+seed*.7)+seed*9);
    float dash = smoothstep(.1f,.5f,travel)*(1-smoothstep(.76f,.94f,travel));
    float streak = (rayCore*.66+softThread*.09)*dash*edge;
    float3 tint = seed > .72 ? float3(1,.58,.08) : mix(float3(.12,.68,1),float3(.65,.35,1),smoothstep(3.0f,10.0f,tier)*.6);
    float3 light = tint*streak;
    float alpha = streak;

    // Two irregular electrical filaments run along the outer frame.
    float jag = blast_noise(float2(uv.x*48,floor(t*8)))-.5;
    float cable = .06+.018*sin(uv.x*19-t*4)+jag*.008;
    float separation = min(abs(uv.y-cable),abs(1-uv.y-cable));
    float electric = exp(-pow(separation/.0016,2.0f));
    float electricGlow = exp(-pow(separation/.012,2.0f));
    float runner = pow(.5+.5*sin(uv.x*7-t*6),6.0f);
    float bolt = (electric*.28+electricGlow*.07)*runner;
    light += float3(.18,.8,1)*bolt;
    alpha += bolt;

    // A single expanding energy ring marks engagement, then clears the centre.
    float ignition = u.animation.z;
    float ring = exp(-pow((r-(.025+u.animation.x*1.9))/.016,2.0f))*ignition*.5;
    float glow = pow(edge,3.0f)*(.04+.008*sin(t*3));
    light += float3(.46,.9,1)*ring + float3(.04,.32,.65)*glow;
    alpha += ring+glow;
    float strength = u.animation.y;
    alpha = min(.62f,alpha)*strength;
    float peak = 1+(clamp(u.animation.w,1.0f,8.0f)-1)*.48;
    return float4(min(light*strength*peak,float3(alpha*peak)),alpha);
  }

  // Adds white light above the drawn frame. Zero alpha keeps the pixels below.
  struct GlintUniforms { float4 scene; float4 clip; float gain; };
  fragment float4 glint_fragment(Vertex v [[stage_in]], texture2d<float> mask [[texture(0)]],
                                 constant GlintUniforms &u [[buffer(0)]]) {
    if (u.gain <= 0 || any(v.uv < u.clip.xy) || any(v.uv >= u.clip.xy+u.clip.zw)) return float4(0);
    constexpr sampler s(filter::nearest,address::clamp_to_zero);
    float glint = mask.sample(s,(v.uv-u.scene.xy)/u.scene.zw).r;
    return float4(float3(glint*u.gain),0);
  }
  """
}

/// Places the arrow glint mask on an HDR overlay. Rectangles are fractions of the overlay.
public struct ArrowGlintUniforms: Sendable {
  public init(scene: SIMD4<Float>, clip: SIMD4<Float>, headroom: Float) {
    self.scene = scene; self.clip = clip
    gain = min(max(0, headroom - 1), Self.peak)
  }
  /// Light the brightest glint adds above SDR white. Arrows are scenery, not a blast.
  public static let peak: Float = 1.5
  public var scene: SIMD4<Float>
  public var clip: SIMD4<Float>
  public var gain: Float
}
