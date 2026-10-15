#!/usr/bin/env python3
"""Build pixel-font design specimens from shaped Tamil masks."""

from __future__ import annotations

import argparse
import base64
import io
import json
import math
from pathlib import Path
import unicodedata

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
BLUE = ["#000040", "#003090", "#0060c0", "#3080d0", "#70a0d1", "#b0c0e0", "#ffdddd"]
PALETTES = {"blue": BLUE, "green": ["#" + c[3:7] + c[1:3] for c in BLUE]}
BG = "#0e1118"
PANEL = "#171e2a"
INK = "#e9edf5"
MUTED = "#a6b3c7"


def colour(value: str) -> tuple[int, int, int, int]:
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def ui_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        Path("/System/Library/Fonts/Supplemental") / ("Arial Bold.ttf" if bold else "Arial.ttf"),
        Path("/usr/share/fonts/truetype/dejavu") / ("DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default(size=size)


def styled_mask(path: Path, sampling: int, threshold: int) -> tuple[Image.Image, list[str]]:
    source = Image.open(path).convert("L")
    size = (source.width // sampling, source.height // sampling)
    if min(size) < 1 or source.width % sampling or source.height % sampling:
        raise ValueError(f"Mask does not match samplingScale: {path}")
    reduced = source.resize(size, Image.Resampling.BOX)
    binary = reduced.point(lambda value: 255 if value >= threshold else 0)
    padded = Image.new("L", (size[0] + 2, size[1] + 2))
    padded.paste(binary, (1, 1))
    dilated = padded.filter(ImageFilter.MaxFilter(3))
    solid = padded.load()
    outline = dilated.load()
    indexed = Image.new("L", padded.size, 255)
    pixels = indexed.load()
    for y in range(padded.height):
        for x in range(padded.width):
            if not outline[x, y]:
                continue
            shade = 0
            if solid[x, y]:
                above = y > 0 and solid[x, y - 1]
                below = y + 1 < padded.height and solid[x, y + 1]
                left = x > 0 and solid[x - 1, y]
                right = x + 1 < padded.width and solid[x + 1, y]
                texture = (x * 73 + y * 151 + x * y * 13) % 97
                shade = 3
                if not above:
                    shade = 4 if texture % 4 else 5
                    if texture < 3:
                        shade = 6
                elif not left:
                    shade = 3 if texture % 3 else 4
                elif not below or not right:
                    shade = 1 if texture % 3 else 2
                elif texture < 14:
                    shade = 2
                elif texture > 88:
                    shade = 4
            pixels[x, y] = shade
    rows = ["".join("." if pixels[x, y] == 255 else str(pixels[x, y]) for x in range(indexed.width))
            for y in range(indexed.height)]
    return indexed, rows


def tint(indexed: Image.Image, palette: str) -> Image.Image:
    colours = [colour(c) for c in PALETTES[palette]]
    image = Image.new("RGBA", indexed.size)
    image.putdata([colours[value] if value != 255 else (0, 0, 0, 0) for value in indexed.get_flattened_data()])
    return image


def sprite_positions(glyphs: list[dict], width: int = 1024) -> tuple[dict, int]:
    positions = {}
    x = y = 3
    row_height = 0
    for glyph in glyphs:
        w, h = glyph["spriteWidth"], glyph["spriteHeight"]
        if x + w + 3 > width:
            x = 3
            y += row_height + 3
            row_height = 0
        positions[glyph["id"]] = {"x": x, "y": y, "width": w, "height": h}
        x += w + 3
        row_height = max(row_height, h)
    return positions, y + row_height + 3


def embed(image: Image.Image) -> str:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def draw_grid(image: Image.Image, box: tuple[int, int, int, int], step: int, baseline: int | None = None) -> None:
    draw = ImageDraw.Draw(image)
    x, y, w, h = box
    for xx in range(x, x + w + 1, step):
        draw.line((xx, y, xx, y + h), fill="#202b3b")
    for yy in range(y, y + h + 1, step):
        draw.line((x, yy, x + w, yy), fill="#202b3b")
    if baseline is not None:
        draw.line((x, baseline, x + w, baseline), fill="#466077")


def tokens(text: str, glyphs: list[dict]) -> list[dict | str]:
    candidates = sorted(((sequence, glyph) for glyph in glyphs
                         if not glyph["diagnosticOnly"] and not glyph["missingGlyph"]
                         for sequence in glyph["inputSequences"]),
                        key=lambda pair: len(pair[0]), reverse=True)
    text = unicodedata.normalize("NFC", text)
    result = []
    index = 0
    while index < len(text):
        if text[index].isspace():
            result.append(text[index])
            index += 1
            continue
        match = next((pair for pair in candidates if text.startswith(pair[0], index)), None)
        if match is None:
            raise ValueError(f"Specimen text is unsupported: {text[index:]} ({ord(text[index]):04X})")
        result.append(match[1])
        index += len(match[0])
    return result


def word_image(text: str, face: dict, sprites: dict, palette: str, scale: int) -> Image.Image:
    run = tokens(text, face["glyphs"])
    glyphs = [g for g in run if isinstance(g, dict)]
    if not glyphs:
        return Image.new("RGBA", (1, 1))
    top = min(g["y"] for g in glyphs)
    bottom = max(g["y"] + g["spriteHeight"] for g in glyphs)
    pen = 2
    width = 4
    for glyph in run:
        if isinstance(glyph, dict):
            width = max(width, pen + glyph["x"] + glyph["spriteWidth"] + 2)
            pen += glyph["advance"]
        else:
            pen += face["bodyHeight"] // 2
    image = Image.new("RGBA", (max(width, pen + 2), bottom - top + 4))
    pen = 2
    for glyph in run:
        if isinstance(glyph, str):
            pen += face["bodyHeight"] // 2
            continue
        image.alpha_composite(sprites[(face["id"], palette, glyph["id"])], (pen + glyph["x"], 2 + glyph["y"] - top))
        pen += glyph["advance"]
    return image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)


def original_sample(reference: Path, face: str, text: str, palette: str, scale: int) -> Image.Image | None:
    path = reference / "original-reference.json"
    if not path.exists():
        return None
    source = json.loads(path.read_text())["faces"][face]
    cw, ch = source["cell_width"], source["cell_height"]
    colours = {p["index"]: tuple(p["rgba"]) for p in source["palette"]}
    image = Image.new("RGBA", (cw * len(text), ch))
    for index, char in enumerate(text):
        glyph = source["glyphs"].get(char)
        if glyph is None:
            continue
        for y, row in enumerate(glyph["rows"]):
            for x, value in enumerate(row):
                if value == ".":
                    continue
                r, g, b, a = colours[value]
                if palette == "green":
                    r, g, b = g, b, r
                image.putpixel((index * cw + glyph["x"] + x, glyph["y"] + y), (r, g, b, a))
    return image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)


def make_overview(output: Path, faces: list[dict], sprites: dict) -> None:
    detail = next((face for face in faces if face["id"] == "detail"), faces[-1])
    hero = word_image("தமிழ்", detail, sprites, "green", 10)
    start_y = 220 + hero.height + 90
    footer_y = start_y + len(faces) * 270 + 210
    image = Image.new("RGBA", (1800, footer_y + 150), BG)
    draw = ImageDraw.Draw(image)
    title = ui_font(48, True)
    body = ui_font(24)
    small = ui_font(20)
    draw.text((64, 46), "TAMIL / PIXEL LETTERING", font=title, fill=INK)
    draw.text((66, 112), "A shaped glyph superset, drawn on a hard pixel grid", font=body, fill=MUTED)
    draw.text((66, 153), "Design experiment  /  Noto outlines with generated pixel finish  /  original colour ramp", font=small, fill=MUTED)
    image.alpha_composite(hero, (64, 220))
    draw.text((64, 220 + hero.height + 20), "TAMIL  /  native glyphs at 10x integer scale", font=small, fill=MUTED)
    y = start_y
    for face in faces:
        draw.rounded_rectangle((50, y, 1750, y + 250), radius=12, fill=PANEL)
        draw.text((74, y + 20), f"{face['id'].upper()}  /  {face['bodyHeight']} px body / {face['lineHeight']} px line", font=body, fill=INK)
        draw.text((74, y + 67), "NATIVE 1X", font=small, fill=MUTED)
        native = word_image("தமிழ்", face, sprites, "green", 1)
        image.alpha_composite(native, (250, y + 64))
        original_face = "Charset1" if face["id"] == "small" else "Charset2"
        original_native = original_sample(ROOT / "reference", original_face, "LEMMINGS", "green", 1)
        if original_native is not None:
            image.alpha_composite(original_native, (470, y + 64))
        draw.text((74, y + 110), "ENLARGED 2X", font=small, fill=MUTED)
        line = word_image("அஆஇஈஉஊஎஏஐஒஓஔ", face, sprites, "blue", 2)
        image.alpha_composite(line, (320, y + 106))
        sample = word_image("க கா கி கீ கு கூ கெ கே கை கொ கோ கௌ க்", face, sprites, "green", 2)
        image.alpha_composite(sample, (74, y + 172))
        y += 270
    draw.text((64, y + 8), "SOURCE STYLE", font=body, fill=INK)
    original = original_sample(ROOT / "reference", "Charset2", "LEMMINGS", "green", 3)
    if original is not None:
        image.alpha_composite(original, (64, y + 48))
        draw.text((520, y + 62), "Local original glyph reference. Excluded from Git.", font=small, fill=MUTED)
    else:
        draw.text((64, y + 52), "Original glyph reference is absent from this checkout.", font=small, fill=MUTED)
    draw.text((64, footer_y), "Draft shapes. Tamil language review required. App integration remains separate.", font=body, fill="#e6be77")
    draw.text((64, footer_y + 42), "Native line heights preserve vowel marks above and below each body. Inspect all glyphs in index.html.", font=small, fill=MUTED)
    image.convert("RGB").save(output / "overview.png", optimize=True)


def make_preview(output: Path, faces: list[dict], sprites: dict) -> None:
    image = Image.new("RGBA", (1200, 530), BG)
    draw = ImageDraw.Draw(image)
    draw.text((36, 24), "TAMIL / LEMMINGS PIXEL FONT STUDY", font=ui_font(30, True), fill=INK)
    draw.text((38, 70), f"{len(faces[0]['glyphs'])} sequences / three sizes / blue and green", font=ui_font(20), fill=MUTED)
    detail = next(face for face in faces if face["id"] == "detail")
    sample = word_image("தமிழ்", detail, sprites, "green", 7)
    image.alpha_composite(sample, (36, 114))
    original = original_sample(ROOT / "reference", "Charset2", "LEMMINGS", "green", 3)
    draw.text((660, 136), "ORIGINAL MENU LETTERING", font=ui_font(17), fill=MUTED)
    if original is not None:
        image.alpha_composite(original, (660, 175))
    draw.text((38, 342), "SMALL FACE / 2X PIXELS", font=ui_font(16), fill=MUTED)
    small = next(face for face in faces if face["id"] == "small")
    vowels = word_image("அ ஆ இ ஈ உ ஊ எ ஏ ஐ ஒ ஓ ஔ", small, sprites, "blue", 2)
    image.alpha_composite(vowels, (36, 370))
    draw.text((38, 461), "Noto outlines with generated pixel finish. Tamil reader review remains open.",
              font=ui_font(20), fill="#e6be77")
    image.convert("RGB").save(output / "preview.png", optimize=True)


def make_sheets(output: Path, faces: list[dict], sprites: dict, groups: dict) -> list[str]:
    files = []
    label_font = ui_font(17, True)
    code_font = ui_font(13)
    for face in faces:
        glyphs = face["glyphs"]
        cell_width = max(270, max(g["spriteWidth"] for g in glyphs) * 3 + 30)
        cell_height = max(165, max(g["spriteHeight"] for g in glyphs) * 3 + 65)
        columns = max(3, 1800 // cell_width)
        per_page = columns * 12
        for page, start in enumerate(range(0, len(glyphs), per_page), 1):
            batch = glyphs[start:start + per_page]
            rows = math.ceil(len(batch) / columns)
            image = Image.new("RGBA", (columns * cell_width + 48, rows * cell_height + 140), BG)
            draw = ImageDraw.Draw(image)
            draw.text((24, 24), f"{face['id'].upper()} / ALL GLYPHS / {page} / GREEN / 3X", font=ui_font(28, True), fill=INK)
            draw.text((24, 67), "Draft pixel shapes. Diagnostic marks include a dotted circle. IDs link to atlas.json.", font=ui_font(18), fill=MUTED)
            for index, glyph in enumerate(batch):
                col = index % columns
                row = index // columns
                x, y = 24 + col * cell_width, 112 + row * cell_height
                draw.rectangle((x + 2, y + 2, x + cell_width - 8, y + cell_height - 6), fill=PANEL)
                label = glyph["label"]
                draw.text((x + 10, y + 9), label[:36], font=label_font, fill=INK)
                draw.text((x + 10, y + 33), " ".join(glyph["codePoints"])[:45], font=code_font, fill=MUTED)
                sprite = sprites[(face["id"], "green", glyph["id"])]
                left = x + (cell_width - sprite.width * 3) // 2
                top = y + 61
                draw_grid(image, (left, top, sprite.width * 3, sprite.height * 3), 3)
                image.alpha_composite(sprite.resize((sprite.width * 3, sprite.height * 3), Image.Resampling.NEAREST), (left, top))
                marker = "MISSING GLYPH" if glyph["missingGlyph"] else "DIAGNOSTIC" if glyph["diagnosticOnly"] else glyph["id"]
                draw.text((x + 10, y + cell_height - 29), marker[:43], font=code_font,
                          fill="#f0918a" if glyph["missingGlyph"] else MUTED)
            name = f"{face['id']}-glyph-sheet-{page:02}.png"
            image.convert("RGB").save(output / name, optimize=True)
            files.append(name)
    return files


HTML = r'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Tamil pixel font experiment</title>
<style>
:root{color-scheme:dark;font:15px/1.45 system-ui,sans-serif;background:#0e1118;color:#e9edf5}*{box-sizing:border-box}body{max-width:1580px;margin:auto;padding:32px}h1{font-size:36px;letter-spacing:.02em;margin:0 0 8px}p{color:#a6b3c7;max-width:1000px}a{color:#a3cfeb}button,input,select{font:inherit;color:inherit;background:#17202e;border:1px solid #40526d;border-radius:7px;padding:9px 12px}label{display:flex;flex-direction:column;gap:5px;color:#a6b3c7;font-size:13px}.controls{display:flex;flex-wrap:wrap;gap:15px;margin:24px 0}.controls input{min-width:240px}.panel{padding:22px;background:#171e2a;border:1px solid #26354b;border-radius:12px;margin:22px 0}.warning{color:#e6be77}.meta{font-size:13px;color:#a6b3c7}.preview-input{width:100%;font-size:24px}canvas{display:block;image-rendering:pixelated}.preview-wrap{overflow:auto;padding:18px 0;min-height:160px}.error{white-space:pre-wrap;color:#ff9a94}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}.card{min-height:165px;padding:15px;background:#171e2a;border:1px solid #26354b;border-radius:8px;overflow:auto}.card h3{font-size:14px;margin:0 0 6px}.card canvas{margin:16px auto}.card .codes{font:11px ui-monospace,monospace;color:#a6b3c7;overflow-wrap:anywhere}.card .sequence{font-size:22px;margin-top:8px}.chip{display:inline-block;padding:2px 7px;margin:0 6px 4px 0;border:1px solid #40526d;border-radius:4px;font-size:11px;color:#a6b3c7}details{margin:15px 0}pre{font:12px/1.5 ui-monospace,monospace;overflow:auto;color:#a6b3c7}#stats{margin:14px 0}input[type=checkbox]{min-width:auto}.samples{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0}.samples button{cursor:pointer}footer{margin:40px 0;color:#a6b3c7;font-size:13px}
</style>
<h1>TAMIL / PIXEL LETTERING</h1>
<p>A shaped glyph superset in the original seven-colour Lemmings ramp. Inspect the pixel sizes, compare palettes and enter Tamil sequences.</p>
<p class="warning">Design experiment. Glyph shapes and legibility require review by a Tamil reader. This specimen does not change the app.</p>
<div class="controls"><label>Face<select id="face"></select></label><label>Palette<select id="palette"><option value="green">Green</option><option value="blue">Blue</option></select></label><label>Enlargement<select id="zoom"><option>2</option><option selected>3</option><option>4</option><option>6</option></select></label><label>Group<select id="group"><option value="">All groups</option></select></label><label>Find a glyph<input id="search" placeholder="Tamil, label, ID or U+0B95"></label><label>Diagnostic entries<input type="checkbox" id="diagnostics"></label></div>
<section class="panel"><label>Tamil sequence preview<input id="previewText" class="preview-input" value="தமிழ்"></label><div class="samples"><button data-text="தமிழ்">தமிழ்</button><button data-text="அஆஇஈஉஊஎஏஐஒஓஔ">Vowels</button><button data-text="க கா கி கீ கு கூ கெ கே கை கொ கோ கௌ க்">Vowel combinations</button></div><div class="preview-wrap"><canvas id="preview"></canvas></div><div id="previewMeta" class="meta"></div><div id="errors" class="error"></div><p class="meta">The preview normalises input to NFC and selects the longest supported sequence. Red boxes show unsupported text.</p></section>
<div id="stats" class="meta"></div><div id="grid" class="grid"></div>
<details class="panel"><summary>Coverage and shaping diagnostics</summary><pre id="coverage"></pre></details>
<footer>Source masks: Core Text with the bundled Noto Tamil fonts. This experiment uses Noto outlines with a generated pixel finish. Pixel styling: hard threshold, one-pixel outline, bevel and restrained texture. Native line heights preserve vowel marks above and below the letter body. See atlas.json and pixel-source.json for source metrics and editable pixel rows. Font licence: SIL Open Font License 1.1.</footer>
<script id="data" type="application/json">__DATA__</script>
<script>
const data=JSON.parse(document.getElementById('data').textContent),byId=id=>document.getElementById(id),images={},faceSelect=byId('face');
for(const f of data.faces){const o=document.createElement('option');o.value=f.id;o.textContent=`${f.id} / ${f.bodyHeight} px body`;faceSelect.append(o)}
for(const g of data.groups){const o=document.createElement('option');o.value=g.id;o.textContent=g.label;byId('group').append(o)}
byId('coverage').textContent=JSON.stringify(data.diagnostics,null,2);
function face(){return data.faces.find(f=>f.id===faceSelect.value)}
function cp(s){return Array.from(s).map(c=>'U+'+c.codePointAt(0).toString(16).toUpperCase().padStart(4,'0')).join(' ')}
function drawGlyph(ctx,g,x,y,scale=1){const p=g.sprite;ctx.imageSmoothingEnabled=false;ctx.drawImage(images[`${face().id}-${byId('palette').value}`],p.x,p.y,p.width,p.height,x,y,p.width*scale,p.height*scale)}
function makeRun(text){const f=face(),list=f.glyphs.filter(g=>!g.diagnosticOnly&&!g.missingGlyph).flatMap(g=>g.inputSequences.map(sequence=>({sequence,glyph:g}))).sort((a,b)=>b.sequence.length-a.sequence.length);let i=0,out=[];text=text.normalize('NFC');while(i<text.length){const c=String.fromCodePoint(text.codePointAt(i));if(/\s/u.test(c)){out.push({space:c});i+=c.length;continue}const match=list.find(candidate=>text.startsWith(candidate.sequence,i));if(match){out.push({glyph:match.glyph});i+=match.sequence.length}else{out.push({unsupported:c,index:Array.from(text.slice(0,i)).length});i+=c.length}}return out}
function preview(){const f=face(),run=makeRun(byId('previewText').value),scale=Number(byId('zoom').value),lineHeight=f.lineHeight+8;let width=12,pen=6,line=0;for(const t of run){if(t.space==='\n'){width=Math.max(width,pen+6);pen=6;line++}else pen+=t.glyph?t.glyph.advance:Math.ceil(f.bodyHeight*.65)}width=Math.max(width,pen+6);const top=Math.min(-f.baseline,...f.glyphs.map(g=>g.y)),height=(line+1)*lineHeight+Math.max(8,-top);const canvas=byId('preview');canvas.width=Math.ceil(width*scale);canvas.height=Math.ceil(height*scale);const ctx=canvas.getContext('2d');ctx.fillStyle='#0e1118';ctx.fillRect(0,0,canvas.width,canvas.height);pen=6;line=0;const problems=[];for(const t of run){if(t.space==='\n'){pen=6;line++;continue}const baseline=4-top+line*lineHeight;if(t.glyph){drawGlyph(ctx,t.glyph,(pen+t.glyph.x)*scale,(baseline+t.glyph.y)*scale,scale);pen+=t.glyph.advance}else if(t.unsupported){const w=Math.ceil(f.bodyHeight*.65);ctx.strokeStyle='#ff7770';ctx.lineWidth=scale;ctx.strokeRect(pen*scale,(baseline-f.bodyHeight)*scale,w*scale,f.bodyHeight*scale);ctx.fillStyle='#ff7770';ctx.font=`${Math.max(10,f.bodyHeight*scale/2)}px monospace`;ctx.fillText('?',(pen+2)*scale,(baseline-2)*scale);pen+=w;problems.push(`Position ${t.index+1}: ${t.unsupported} (${cp(t.unsupported)})`)}else pen+=Math.ceil(f.bodyHeight*.65)}byId('errors').textContent=problems.length?'Unsupported input:\n'+problems.join('\n'):'';byId('previewMeta').textContent=`${run.filter(t=>t.glyph).length} matched sprites / ${scale}x pixels / ${f.bodyHeight} px body / longest NFC sequence match`}
function render(){const f=face(),query=byId('search').value.toLocaleLowerCase(),group=byId('group').value,diagnostic=byId('diagnostics').checked,scale=Number(byId('zoom').value);const filtered=f.glyphs.filter(g=>(diagnostic||!g.diagnosticOnly)&&(!group||g.group===group)&&(!query||[g.sequence,g.label,g.id,g.codePoints.join(' ')].join(' ').toLocaleLowerCase().includes(query)));const grid=byId('grid');grid.replaceChildren();for(const g of filtered){const card=document.createElement('article');card.className='card';const title=document.createElement('h3');title.textContent=g.label;card.append(title);const codes=document.createElement('div');codes.className='codes';codes.textContent=g.codePoints.join(' ');card.append(codes);const canvas=document.createElement('canvas');canvas.width=g.sprite.width*scale;canvas.height=g.sprite.height*scale;drawGlyph(canvas.getContext('2d'),g,0,0,scale);card.append(canvas);const meta=document.createElement('div');meta.className='meta';meta.textContent=`${g.advance} px advance · ${g.sprite.width}×${g.sprite.height} sprite`;card.append(meta);const state=document.createElement('div');state.className='meta';state.textContent=g.missingGlyph?'Missing source glyph':g.diagnosticOnly?'Diagnostic mark / dotted circle':g.id;card.append(state);const details=document.createElement('details'),summary=document.createElement('summary'),pre=document.createElement('pre');summary.textContent='Source shaping';pre.textContent=JSON.stringify({sequence:g.sequence,glyphIds:g.glyphIds,sourceFonts:g.sourceFonts,x:g.x,y:g.y,diagnosticOnly:g.diagnosticOnly},null,2);details.append(summary,pre);card.append(details);grid.append(card)}byId('stats').textContent=`${filtered.length} of ${f.glyphs.length} glyphs / ${data.diagnostics.inventoryCount} requested entries / ${data.diagnostics.missingGlyphCount} missing source glyphs across all faces`;preview()}
Promise.all(Object.entries(data.images).map(([name,src])=>new Promise((resolve,reject)=>{const i=new Image;i.onload=()=>{images[name]=i;resolve()};i.onerror=reject;i.src=src}))).then(()=>{render();for(const id of ['face','palette','zoom','group','diagnostics'])byId(id).addEventListener('change',render);byId('search').addEventListener('input',render);byId('previewText').addEventListener('input',preview);for(const button of document.querySelectorAll('[data-text]'))button.addEventListener('click',()=>{byId('previewText').value=button.dataset.text;preview()})});
</script></html>'''


def build(raw: Path, repertoire_path: Path, output: Path, threshold: int) -> dict:
    manifest = json.loads((raw / "manifest.json").read_text())
    repertoire = json.loads(repertoire_path.read_text())
    entries = {entry["id"]: entry for entry in repertoire["entries"]}
    groups = {group["id"]: group for group in repertoire["groups"]}
    output.mkdir(parents=True, exist_ok=True)
    faces = []
    sprites = {}
    source_faces = []
    image_data = {}
    missing = []
    absent = []
    for raw_face in manifest["faces"]:
        face = {k: raw_face[k] for k in ("id", "bodyHeight", "baseline", "lineHeight")}
        glyphs = []
        pixel_glyphs = []
        for raw_glyph in raw_face["glyphs"]:
            unknown_fonts = [name for name in raw_glyph.get("sourceFonts", []) if not name.startswith("Noto")]
            if unknown_fonts:
                raise ValueError(f"Unapproved source font for {raw_glyph['id']}: {unknown_fonts}")
            entry = entries.get(raw_glyph["id"], {})
            text = raw_glyph["text"]
            indexed, rows = styled_mask(raw / raw_glyph["mask"], manifest["samplingScale"], threshold)
            glyph = {
                "id": raw_glyph["id"], "sequence": unicodedata.normalize("NFC", text),
                "originalSequence": text, "displayText": raw_glyph.get("displayText", text),
                "inputSequences": sorted({unicodedata.normalize("NFC", sequence)
                    for sequence in [text] + [alias["text"] for alias in entry.get("aliases", [])]}),
                "aliases": entry.get("aliases", []),
                "label": entry.get("label", raw_glyph["id"]), "group": entry.get("group", "other"),
                "codePoints": entry.get("codePoints", [f"U+{ord(c):04X}" for c in text]),
                "advance": raw_glyph["advance"], "x": raw_glyph["x"] - 1, "y": raw_glyph["y"] - 1,
                "spriteWidth": indexed.width, "spriteHeight": indexed.height,
                "glyphIds": raw_glyph.get("glyphIds", []), "sourceFonts": raw_glyph.get("sourceFonts", []),
                "missingGlyph": raw_glyph.get("missingGlyph", False),
                "diagnosticOnly": raw_glyph.get("diagnosticOnly", False),
            }
            if glyph["missingGlyph"]:
                missing.append({"face": face["id"], "id": glyph["id"], "sequence": text})
            glyphs.append(glyph)
            pixel_glyphs.append({"id": glyph["id"], "sequence": glyph["sequence"], "rows": rows})
            for palette in PALETTES:
                sprites[(face["id"], palette, glyph["id"])] = tint(indexed, palette)
        present = {g["id"] for g in glyphs}
        absent.extend({"face": face["id"], "id": key} for key in entries.keys() - present)
        positions, atlas_height = sprite_positions(glyphs)
        for glyph in glyphs:
            glyph["sprite"] = positions[glyph["id"]]
        face["glyphs"] = glyphs
        face["atlas"] = {"width": 1024, "height": atlas_height,
                         "files": {p: f"{face['id']}-{p}.png" for p in PALETTES}}
        for palette in PALETTES:
            atlas = Image.new("RGBA", (1024, atlas_height))
            for glyph in glyphs:
                pos = glyph["sprite"]
                atlas.alpha_composite(sprites[(face["id"], palette, glyph["id"])], (pos["x"], pos["y"]))
            atlas.save(output / face["atlas"]["files"][palette], optimize=True)
            image_data[f"{face['id']}-{palette}"] = embed(atlas)
        faces.append(face)
        source_faces.append({"id": face["id"], "glyphs": pixel_glyphs})
    collisions = []
    for face in faces:
        by_sequence = {}
        for glyph in face["glyphs"]:
            if glyph["sequence"] in by_sequence:
                collisions.append({"face": face["id"], "sequence": glyph["sequence"],
                                   "ids": [by_sequence[glyph["sequence"]], glyph["id"]]})
            by_sequence[glyph["sequence"]] = glyph["id"]
        face["sequenceToSprite"] = {sequence: g["id"] for g in face["glyphs"]
                                    if not g["diagnosticOnly"] and not g["missingGlyph"]
                                    for sequence in g["inputSequences"]}
    diagnostics = {"inventoryCount": len(entries), "faceCount": len(faces),
                   "renderedGlyphCount": sum(len(f["glyphs"]) for f in faces),
                   "missingGlyphCount": len(missing), "missingGlyphs": missing,
                   "absentInventoryEntries": absent, "canonicalSequenceCollisions": collisions,
                   "diagnosticGlyphCount": sum(g["diagnosticOnly"] for f in faces for g in f["glyphs"]),
                   "reviewStatus": "Design experiment. Tamil language review and app integration remain open.",
                   "repertoireSummary": repertoire.get("summary", {})}
    atlas = {"version": 1, "normalisation": "NFC", "samplingScale": manifest["samplingScale"],
             "threshold": threshold, "outlinePadding": 1,
             "paletteIndex": "0-6 = opaque ramp; . = transparent", "palettes": PALETTES,
             "metrics": "Native pixels. x/y locate sprite top-left relative to pen/baseline; advance moves the pen.",
             "source": "Noto outlines with a generated pixel finish. Original Lemmings seven-colour ramp.",
             "fontSources": manifest.get("fontSources", []), "renderer": manifest.get("renderer"),
             "groups": list(groups.values()), "faces": faces, "diagnostics": diagnostics}
    (output / "atlas.json").write_text(json.dumps(atlas, ensure_ascii=False, indent=2) + "\n")
    (output / "pixel-source.json").write_text(json.dumps({"version": 1, "palettes": PALETTES,
        "transparent": ".", "faces": source_faces}, ensure_ascii=False, indent=2) + "\n")
    make_overview(output, faces, sprites)
    make_preview(output, faces, sprites)
    sheets = make_sheets(output, faces, sprites, groups)
    payload = {"faces": faces, "groups": list(groups.values()), "diagnostics": diagnostics, "images": image_data}
    html_data = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    (output / "index.html").write_text(HTML.replace("__DATA__", html_data))
    (output / "diagnostics.json").write_text(json.dumps({**diagnostics, "glyphSheets": sheets}, ensure_ascii=False, indent=2) + "\n")
    return diagnostics


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw", type=Path, default=ROOT / "output" / "raw")
    parser.add_argument("--repertoire", type=Path, default=ROOT / "repertoire.json")
    parser.add_argument("--output", type=Path, default=ROOT / "output")
    parser.add_argument("--threshold", type=int, default=112)
    args = parser.parse_args()
    diagnostics = build(args.raw, args.repertoire, args.output, args.threshold)
    print(json.dumps({key: diagnostics[key] for key in ("inventoryCount", "faceCount", "renderedGlyphCount", "missingGlyphCount")}, indent=2))


if __name__ == "__main__":
    main()
