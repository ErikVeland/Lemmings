#!/usr/bin/env python3
"""Check repertoire coverage, font provenance and raster masks for the experiment."""

from collections import Counter, defaultdict
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import unicodedata

from PIL import Image


ROOT = Path(__file__).resolve().parent
THRESHOLD = 112
SCALE = 4
ALLOWED_FONTS = {
    "NotoSansTamil-Bold",
    "NotoSansTamilSupplement-NotoSansTamilSupplementRegular",
    "NotoSans-Bold",
}
FONT_FILES = {
    "NotoSansTamil-Bold.ttf",
    "NotoSansTamilSupplement-Regular.ttf",
    "NotoSans-Bold.ttf",
}
CONSONANTS = (
    0x0B95, 0x0B99, 0x0B9A, 0x0B9E, 0x0B9F, 0x0BA3, 0x0BA4,
    0x0BA8, 0x0BAA, 0x0BAE, 0x0BAF, 0x0BB0, 0x0BB2, 0x0BB5,
    0x0BB4, 0x0BB3, 0x0BB1, 0x0BA9, 0x0B9C, 0x0BB6, 0x0BB7,
    0x0BB8, 0x0BB9,
)
VOWEL_SIGNS = (0x0BBE, 0x0BBF, 0x0BC0, 0x0BC1, 0x0BC2, 0x0BC6,
               0x0BC7, 0x0BC8, 0x0BCA, 0x0BCB, 0x0BCC)
PULLI = "\u0bcd"
KSSA = "\u0b95\u0bcd\u0bb7"
SHRII = "\u0bb6\u0bcd\u0bb0\u0bc0"


def code_points(text):
    """Return the standard code point labels for a text sequence."""
    return [f"U+{ord(character):04X}" for character in text]


def add_issue(issues, code, message, **context):
    """Record an actionable issue with its source context."""
    issues.append({"code": code, "message": message, **context})


def read_json(path, errors):
    """Read an input document and record missing or malformed data."""
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as error:
        add_issue(errors, "input-unreadable", str(error), file=str(path.relative_to(ROOT)))
        return None


def verify_inventory(repertoire, errors, counts):
    """Check normalisation, group totals and the documented Tamil coverage boundary."""
    entries = repertoire.get("entries", [])
    ids = [entry.get("id") for entry in entries]
    texts = [entry.get("text") for entry in entries]
    for field, values in (("id", ids), ("text", texts)):
        duplicates = [value for value, total in Counter(values).items() if total > 1]
        if duplicates:
            add_issue(errors, "inventory-duplicate", f"Repertoire {field} values must be unique.",
                      field=field, values=duplicates)

    alias_count = 0
    for entry in entries:
        text = entry.get("text")
        entry_id = entry.get("id")
        if not isinstance(text, str) or not text:
            add_issue(errors, "inventory-text", "Each repertoire entry needs non-empty text.", id=entry_id)
            continue
        if unicodedata.normalize("NFC", text) != text:
            add_issue(errors, "inventory-nfc", "Repertoire text must use NFC.", id=entry_id)
        if entry.get("codePoints") != code_points(text):
            add_issue(errors, "inventory-code-points", "Code points do not match the entry text.", id=entry_id)
        expected_id = "-".join(f"{ord(character):04X}" for character in text)
        if entry_id != expected_id:
            add_issue(errors, "inventory-id", "Entry ID does not match its code points.",
                      id=entry_id, expected=expected_id)
        for alias in entry.get("aliases", []):
            alias_count += 1
            alias_text = alias.get("text", "")
            if alias.get("codePoints") != code_points(alias_text):
                add_issue(errors, "alias-code-points", "Alias code points do not match its text.", id=entry_id)
            if alias.get("relationship") == "canonical-equivalent":
                if unicodedata.normalize("NFC", alias_text) != text:
                    add_issue(errors, "alias-equivalence", "Canonical alias does not normalise to its entry.", id=entry_id)
                if alias.get("normalisation") == "NFD" and unicodedata.normalize("NFD", alias_text) != alias_text:
                    add_issue(errors, "alias-nfd", "An NFD alias must use NFD.", id=entry_id)
            elif alias.get("relationship") == "unicode-recommended-equivalent":
                if text != SHRII or alias_text != "\u0bb8\u0bcd\u0bb0\u0bc0":
                    add_issue(errors, "alias-recommended-equivalence", "The recommended alias must be the documented shrii spelling.", id=entry_id)
            else:
                add_issue(errors, "alias-relationship", "Alias relationship is not recognised.", id=entry_id)

    groups = repertoire.get("groups", [])
    group_ids = [group.get("id") for group in groups]
    actual_groups = Counter(entry.get("group") for entry in entries)
    if len(set(group_ids)) != len(group_ids):
        add_issue(errors, "group-duplicate", "Repertoire group IDs must be unique.")
    if set(actual_groups) != set(group_ids):
        add_issue(errors, "group-membership", "Declared groups do not match entry groups.")
    for group in groups:
        actual = actual_groups[group.get("id")]
        if actual != group.get("entryCount"):
            add_issue(errors, "group-count", "Group total does not match its entries.",
                      group=group.get("id"), expected=group.get("entryCount"), actual=actual)
    summary = repertoire.get("summary", {})
    if summary.get("entryCount") != len(entries):
        add_issue(errors, "inventory-count", "Summary entry count does not match the inventory.")
    if summary.get("groupCounts") != dict(actual_groups):
        add_issue(errors, "inventory-group-counts", "Summary group counts do not match the inventory.")

    text_set = {text for text in texts if isinstance(text, str)}
    consonant_forms = {chr(cp) + suffix for cp in CONSONANTS
                       for suffix in ("", PULLI, *(chr(sign) for sign in VOWEL_SIGNS))}
    named_sequences = {chr(cp) + suffix for cp in CONSONANTS
                       for suffix in (PULLI, *(chr(sign) for sign in VOWEL_SIGNS))}
    kssa_forms = {KSSA + suffix for suffix in ("", PULLI, *(chr(sign) for sign in VOWEL_SIGNS))}
    named_sequences |= kssa_forms | {SHRII}
    claimed_named = {entry["text"] for entry in entries
                     if "ucd-named-sequences" in entry.get("sources", [])}
    for name, expected in (("23 consonants × 13 forms", consonant_forms),
                           ("13 kssa forms", kssa_forms),
                           ("290 approved Tamil named sequences", named_sequences)):
        missing = expected - text_set
        if missing:
            add_issue(errors, "inventory-coverage", f"Missing entries from {name}.",
                      missing=[{"text": text, "codePoints": code_points(text)} for text in sorted(missing)])
    if claimed_named != named_sequences or len(claimed_named) != 290:
        add_issue(errors, "named-sequence-coverage", "The named-sequence source must identify the 290 approved Tamil sequences.",
                  missing=[code_points(text) for text in sorted(named_sequences - claimed_named)],
                  unexpected=[code_points(text) for text in sorted(claimed_named - named_sequences)])
    counts.update(repertoireEntries=len(entries), repertoireGroups=len(groups), aliases=alias_count,
                  consonantForms=len(consonant_forms & text_set), kssaForms=len(kssa_forms & text_set),
                  approvedTamilNamedSequences=len(claimed_named))
    return {entry["id"]: entry for entry in entries if isinstance(entry.get("text"), str)}


def verify_vendor(sources, errors, counts):
    """Check the recorded hashes of downloaded fonts and licence files."""
    records = sources.get("sources", [])
    files = [record.get("file") for record in records]
    if len(set(files)) != len(files):
        add_issue(errors, "vendor-duplicate", "Vendor source files must be unique.")
    if not FONT_FILES.issubset(files):
        add_issue(errors, "vendor-font-coverage", "Each source font needs a recorded SHA-256.",
                  missing=sorted(FONT_FILES - set(files)))
    checked = 0
    for source in records:
        filename = source.get("file", "")
        path = ROOT / "vendor" / filename
        if not filename or path.resolve().parent != (ROOT / "vendor").resolve():
            add_issue(errors, "vendor-path", "Vendor source must name a file in vendor/.", file=filename)
            continue
        try:
            digest = sha256(path.read_bytes()).hexdigest()
        except OSError as error:
            add_issue(errors, "vendor-unreadable", str(error), file=filename)
            continue
        checked += 1
        if digest != source.get("sha256"):
            add_issue(errors, "vendor-hash", "Vendor file does not match its recorded SHA-256.",
                      file=filename, actual=digest, expected=source.get("sha256"))
    if not records:
        add_issue(errors, "vendor-empty", "The vendor source inventory is empty.")
    counts["vendorFilesChecked"] = checked


def verify_masks(manifest, entries, errors, warnings, counts):
    """Check shaped glyph coverage, source ink bounds and pixel silhouette collisions."""
    if manifest.get("samplingScale") != SCALE:
        add_issue(errors, "sampling-scale", "Raw masks must use a sampling scale of four.")
    font_sources = manifest.get("fontSources", [])
    recorded_fonts = {source.get("postScriptName") for source in font_sources}
    if recorded_fonts != ALLOWED_FONTS:
        add_issue(errors, "manifest-fonts", "Manifest font sources do not match the three vendored fonts.",
                  actual=sorted(str(font) for font in recorded_fonts))
    if {source.get("file") for source in font_sources} != {f"vendor/{name}" for name in FONT_FILES}:
        add_issue(errors, "manifest-font-files", "Manifest font files do not match the hashed vendor files.")
    faces = manifest.get("faces", [])
    face_ids = [face.get("id") for face in faces]
    if not faces or len(set(face_ids)) != len(face_ids):
        add_issue(errors, "face-ids", "Manifest needs faces with unique IDs.")
    checked_masks = 0
    face_counts = {}
    raw_root = ROOT / "output" / "raw"
    for face in faces:
        face_id = face.get("id")
        glyphs = face.get("glyphs", [])
        glyph_ids = [glyph.get("id") for glyph in glyphs]
        if len(set(glyph_ids)) != len(glyph_ids):
            add_issue(errors, "glyph-duplicate", "A face must contain each entry once.", face=face_id)
        if set(glyph_ids) != set(entries):
            add_issue(errors, "face-coverage", "Face entries do not match the repertoire.", face=face_id,
                      missing=sorted(set(entries) - set(glyph_ids)),
                      unexpected=sorted(set(glyph_ids) - set(entries)))
        silhouettes = defaultdict(list)
        for glyph in glyphs:
            entry_id = glyph.get("id")
            entry = entries.get(entry_id)
            context = {"face": face_id, "id": entry_id}
            if entry is None:
                continue
            if glyph.get("text") != entry["text"]:
                add_issue(errors, "glyph-text", "Shaped text does not match the repertoire entry.", **context)
            ids = glyph.get("glyphIds", [])
            if glyph.get("missingGlyph") or not ids or 0 in ids:
                add_issue(errors, "missing-glyph", "The shaped sequence contains a missing glyph.", **context)
            fonts = glyph.get("sourceFonts", [])
            if not fonts or set(fonts) - ALLOWED_FONTS:
                add_issue(errors, "unexpected-font", "The shaped sequence uses an unexpected fallback font.",
                          sourceFonts=fonts, **context)
            width, height = glyph.get("width"), glyph.get("height")
            if any(not isinstance(value, int) or value <= 0 for value in (width, height)):
                add_issue(errors, "glyph-metrics", "Mask width and height must be positive integers.", **context)
                continue
            mask = glyph.get("mask", "")
            path = raw_root / mask
            if not mask or not path.resolve().is_relative_to(raw_root.resolve()):
                add_issue(errors, "mask-path", "Mask must be a file inside output/raw/.", **context)
                continue
            try:
                with Image.open(path) as image:
                    image.load()
                    raw = image.convert("L")
            except (OSError, ValueError) as error:
                add_issue(errors, "mask-unreadable", str(error), mask=mask, **context)
                continue
            checked_masks += 1
            if raw.size != (width * SCALE, height * SCALE):
                add_issue(errors, "mask-size", "Raw mask dimensions do not equal four times the glyph metrics.",
                          actual=list(raw.size), expected=[width * SCALE, height * SCALE], **context)
                continue
            ink = raw.getbbox()
            if ink and (ink[0] == 0 or ink[1] == 0 or ink[2] == raw.width or ink[3] == raw.height):
                add_issue(errors, "source-ink-clipped", "Source ink touches the raw image boundary. Increase the raster bounds.",
                          inkBounds=list(ink), **context)
            pixels = raw.resize((width, height), Image.Resampling.BOX)
            pixels = pixels.point(lambda value: 255 if value >= THRESHOLD else 0)
            ink = pixels.getbbox()
            if not ink:
                if entry["text"] != " ":
                    add_issue(errors, "blank-pixel-mask", "A non-space entry has no pixels at threshold 112.", **context)
                continue
            cropped = pixels.crop(ink)
            silhouette = (cropped.size, cropped.tobytes())
            silhouettes[silhouette].append({"id": entry_id, "label": entry["label"], "text": entry["text"]})
        collisions = [matches for matches in silhouettes.values() if len(matches) > 1]
        for matches in collisions:
            add_issue(warnings, "silhouette-collision", "Distinct entries share an exact cropped pixel silhouette.",
                      face=face_id, threshold=THRESHOLD, entries=matches)
        face_counts[face_id] = {"entries": len(glyphs), "silhouetteCollisionGroups": len(collisions)}
    counts.update(faces=face_counts, masksChecked=checked_masks,
                  silhouetteCollisionGroups=sum(face["silhouetteCollisionGroups"] for face in face_counts.values()))


def main():
    """Write a report and fail the build when a structural check fails."""
    errors, warnings, counts = [], [], {}
    repertoire = read_json(ROOT / "repertoire.json", errors)
    sources = read_json(ROOT / "vendor" / "sources.json", errors)
    manifest = read_json(ROOT / "output" / "raw" / "manifest.json", errors)
    entries = verify_inventory(repertoire, errors, counts) if repertoire else {}
    if sources:
        verify_vendor(sources, errors, counts)
    if manifest and entries:
        verify_masks(manifest, entries, errors, warnings, counts)
    report = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "pass": not errors,
        "threshold": THRESHOLD,
        "samplingScale": SCALE,
        "method": "Check source ink bounds. BOX-downsample masks to recorded metrics, threshold at 112, and compare cropped silhouettes.",
        "limitations": "Structural checks do not prove Tamil legibility, correct letter shapes or a visual match to Lemmings artwork.",
        "counts": counts,
        "errors": errors,
        "warnings": warnings,
    }
    destination = ROOT / "output" / "verification.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    status = "PASS" if report["pass"] else "FAIL"
    print(f"{status}: {counts.get('repertoireEntries', 0)} entries, "
          f"{counts.get('masksChecked', 0)} masks, {len(errors)} errors, "
          f"{len(warnings)} silhouette warnings. Report: {destination}")
    for error in errors[:10]:
        location = "/".join(str(error[key]) for key in ("face", "id") if key in error)
        print(f"  {error['code']}{' ' + location if location else ''}: {error['message']}")
    return 0 if report["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
