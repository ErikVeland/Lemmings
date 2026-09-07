#!/usr/bin/env python3
"""Measure authored DOS/Mac pairs without interpolating either source."""
import collections
import json
import pathlib
import sys
import numpy as np
from PIL import Image, ImageDraw

root = pathlib.Path(sys.argv[1])
records = json.loads((root / 'manifest.json').read_text())

def read(record, key):
    r = record[key]
    return np.frombuffer((root / r['file']).read_bytes(), np.uint8).reshape(r['height'], r['width'], 4)

def aligned(record):
    d, m = read(record, 'dos'), read(record, 'mac')
    canvas = np.zeros((d.shape[0]*2, d.shape[1]*2, 4), np.uint8)
    ox = record['mac']['x'] - record['dos']['x']*2
    oy = record['mac']['y'] - record['dos']['y']*2
    # Classic Mac sprite origins are stored relative to a different actor point.
    # Retain raw origins in the manifest; use best integer translation for measurement.
    if record['category'] == 'sprite':
        n = d.repeat(2, 0).repeat(2, 1)[..., 3] != 0
        best = (-1, 0, 0)
        for y in range(-m.shape[0], canvas.shape[0]):
            for x in range(-m.shape[1], canvas.shape[1]):
                x0, y0 = max(0,x), max(0,y)
                x1, y1 = min(canvas.shape[1],x+m.shape[1]), min(canvas.shape[0],y+m.shape[0])
                if x1<=x0 or y1<=y0: continue
                mask = m[y0-y:y1-y,x0-x:x1-x,3] != 0
                intersection = (mask & n[y0:y1,x0:x1]).sum()
                union = (m[...,3] != 0).sum()+n.sum()-intersection
                score = intersection / max(1,union)
                if score > best[0]: best = (score,x,y)
        _,ox,oy=best
    x0,y0=max(0,ox),max(0,oy)
    x1,y1=min(canvas.shape[1],ox+m.shape[1]),min(canvas.shape[0],oy+m.shape[0])
    if x1>x0 and y1>y0: canvas[y0:y1,x0:x1] = m[y0-oy:y1-oy,x0-ox:x1-ox]
    return d,canvas,(ox,oy)

if __name__ == '__main__':
    metrics=collections.defaultdict(collections.Counter)
    alignment=[]
    selected=[]
    for r in records:
        # All terrain and objects, plus a representative sample of each sprite sequence.
        if r['category']=='sprite' and not r['name'].endswith('-0'): continue
        d,m,offset=aligned(r)
        n=d.repeat(2,0).repeat(2,1)
        group=r['name'].split('-')[0]+'/'+r['category']
        c=metrics[group]
        c['pairs']+=1; c['pixels']+=m.shape[0]*m.shape[1]
        c['alpha_different']+=int((n[...,3]!=m[...,3]).sum())
        c['rgba_different']+=int(np.any(n!=m,axis=2).sum())
        b=m.reshape(d.shape[0],2,d.shape[1],2,4).transpose(0,2,1,3,4).reshape(-1,4,4)
        occupied=np.any(b[...,3]!=0,axis=1)
        c['occupied_blocks']+=int(occupied.sum())
        c['split_blocks']+=int((np.any(b!=b[:,:1,:],axis=(1,2)) & occupied).sum())
        c['exact_dimensions']+=int(r['mac']['width']==2*r['dos']['width'] and r['mac']['height']==2*r['dos']['height'])
        alignment.append(dict(name=r['name'],offset=offset))
        if r['name'] in ['lemmings-terrain-0-0','lemmings-terrain-1-0','lemmings-terrain-2-0',
            'ohno-terrain-0-0','ohno-terrain-1-0','holiday-terrain-2-0','xmas-terrain-2-0',
            'lemmings-sprite-walking-right-0','lemmings-sprite-building-right-0',
            'lemmings-object-0-0-0','lemmings-object-0-1-0','lemmings-object-0-5-0']:
            selected.append((r,d,m,n))
    result={g:dict(c) for g,c in metrics.items()}
    (root.parent/'measurements.json').write_text(json.dumps(result,indent=2))
    (root.parent/'alignment.json').write_text(json.dumps(alignment,indent=2))
    w=1260
    heights=[max(d.shape[0]*4,m.shape[0]*4)+35 for _,d,m,n in selected]
    sheet=Image.new('RGB',(w,sum(heights)+45),(26,26,30)); draw=ImageDraw.Draw(sheet)
    draw.text((10,10),'Original DOS (4x)                       Original Mac (4x)                      DOS nearest neighbour 2x (4x)',fill='white')
    y=40
    for (r,d,m,n),height in zip(selected,heights):
        draw.text((10,y),r['name'],fill='white')
        for x,a in zip((10,420,840),(d,m,n)):
            im=Image.fromarray(a).resize((a.shape[1]*4,a.shape[0]*4),Image.Resampling.NEAREST)
            sheet.paste(im,(x,y+20),im)
        y+=height
    sheet.save(root.parent/'reference-study.png')
    print(json.dumps(result,indent=2))
