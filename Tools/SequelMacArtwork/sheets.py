#!/usr/bin/env python3
"""Build A–F evidence sheets and integer-zoom animation strips from local pixels."""
import json
import pathlib
import sys
import numpy as np
from PIL import Image, ImageDraw

base=pathlib.Path(sys.argv[1])
proof=base/'proof-v2'
out=base/'comparisons';out.mkdir(exist_ok=True)
refs={r['name']:r for r in json.loads((base/'references/manifest.json').read_text())}
alignment={r['name']:r['offset'] for r in json.loads((base/'alignment.json').read_text())}
records=json.loads((proof/'manifest.json').read_text())
byname={r['name']:r for r in records}

def rgba(r,kind):
    d=r[kind]
    return Image.frombytes('RGBA',(d['width'],d['height']),(base/'references'/d['file']).read_bytes())

def reference(name):
    r=refs[name];a=rgba(r,'dos');b=rgba(r,'mac')
    c=a.resize((a.width*2,a.height*2),Image.Resampling.NEAREST)
    aligned=Image.new('RGBA',c.size)
    x,y=alignment[name]
    aligned.paste(b,(x,y))
    d=Image.open(proof/('ref-'+name+'-mac.png')).convert('RGBA')
    return [a,aligned,c,d]

def crop_pair(a,b):
    if a.width<=120 and a.height<=76:return a,b,False
    pixels=np.asarray(a)
    best=(-1,0,0)
    w,h=min(120,a.width),min(76,a.height)
    for y in range(0,max(1,a.height-h+1),16):
        for x in range(0,max(1,a.width-w+1),16):
            cut=pixels[y:y+h,x:x+w,:3]
            score=int(np.any(cut[:,1:]!=cut[:,:-1],axis=2).sum())
            if score>best[0]:best=(score,x,y)
    _,x,y=best
    return a.crop((x,y,x+w,y+h)),b.crop((x*2,y*2,(x+w)*2,(y+h)*2)),True

def choose_ref(name):
    if 'walker' in name or 'sprite' in name:return 'lemmings-sprite-walking-right-0'
    if '-LM' in name:return 'lemmings-sprite-building-right-0'
    if 'type2-' in name:return 'lemmings-object-0-1-0'
    if 'type6-' in name:return 'lemmings-object-0-5-0'
    if 'object' in name:return 'lemmings-object-0-0-0'
    if '20-' in name or '70-' in name:return 'lemmings-terrain-0-0'
    if name.startswith('l3-level-1'):return 'ohno-terrain-1-0'
    return 'ohno-terrain-0-0'

selections={
 'l2':['l2-walker-0','l2-walker-1','l2-walker-2','l2-LM05-0','l2-LM19-0','l2-LM26-0']+
     [r['name'] for r in records if r['name'].startswith('l2-object-tribe0') and r['name'].endswith('-0')]+
     ['l2-level-20-terrain','l2-level-40-terrain','l2-level-70-terrain'],
 'l3':['l3-sprite-1-0-0','l3-sprite-1-0-1','l3-sprite-1-0-2','l3-sprite-2-4-0','l3-sprite-3-8-0']+
     [r['name'] for r in records if r['name'].startswith('l3-object-') and r['name'].endswith('-0')][:6]+
     ['l3-level-1','l3-level-101','l3-level-201']}
for game,names in selections.items():
    names=[n for n in names if n in byname]
    for page in range(0,len(names),5):
        sheet=Image.new('RGB',(1740,1100),(22,24,30));draw=ImageDraw.Draw(sheet)
        draw.text((12,10),f'{game.upper()} / Macintosh reconstruction evidence / page {page//5+1}',fill='white')
        titles=['A  DOS reference','B  Authored Macintosh','C  Nearest neighbour 2x','D  Inferred treatment','E  Sequel PC source','F  Sequel reconstruction']
        for i,title in enumerate(titles):draw.text((i*290+10,38),title,fill='#bfc9d9')
        for row,name in enumerate(names[page:page+5]):
            ref=choose_ref(name);images=reference(ref)
            a=Image.open(proof/(name+'-pc.png')).convert('RGBA')
            b=Image.open(proof/(name+'-mac.png')).convert('RGBA')
            a,b,cropped=crop_pair(a,b)
            # Keep large reference terrain crops registered across all four columns.
            if images[0].width>120 or images[0].height>76:
                images[0]=images[0].crop((0,0,min(120,images[0].width),min(76,images[0].height)))
                for i in range(1,4):images[i]=images[i].crop((0,0,images[0].width*2,images[0].height*2))
            images += [a,b]
            y=78+row*202
            draw.text((12,y),ref+'   ->   '+name+(' (registered crop)' if cropped else ''),fill='white')
            maximum=max(im.width*(2 if i in (0,4) else 1) for i,im in enumerate(images))
            height=max(im.height*(2 if i in (0,4) else 1) for i,im in enumerate(images))
            scale=max(1,min(4,270//maximum,170//height))
            for i,im in enumerate(images):
                factor=scale*(2 if i in (0,4) else 1)
                enlarged=im.resize((im.width*factor,im.height*factor),Image.Resampling.NEAREST)
                sheet.paste(enlarged,(i*290+12,y+22),enlarged)
        draw.text((12,1080),'All zoom is integer. B uses measured registration. D/F retain PC opacity; the authored Mac silhouette may differ.',fill='#bfc9d9')
        sheet.save(out/f'{game}-ABCDEF-{page//5+1}.png')

# Adjacent frames at native reconstruction size and at 4x integer zoom.
for game,prefix in [('l2','l2-walker-'),('l3','l3-sprite-1-0-')]:
    names=[r['name'] for r in records if r['name'].startswith(prefix)]
    sheet=Image.new('RGB',(1200,560),(22,24,30));draw=ImageDraw.Draw(sheet)
    draw.text((10,10),f'{game.upper()} animation: top native 2x artwork; below integer 4x zoom',fill='white')
    for i,name in enumerate(names[:8]):
        im=Image.open(proof/(name+'-mac.png')).convert('RGBA')
        x=12+i*145
        sheet.paste(im,(x,45),im)
        big=im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST)
        sheet.paste(big,(x,150),big)
    sheet.save(out/f'{game}-animation.png')
print(f'Wrote comparison sheets to {out}')
