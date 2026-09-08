#!/usr/bin/env python3
"""Compile discrete, category-specific pixel substitution tables from the study.

These are exact neighbourhood lookups, not a neural or continuous-image model.
Each output nibble selects an existing colour in the source neighbourhood.
"""
import collections
import hashlib
import json
import pathlib
import sys
import numpy as np
from analyse import records, read, root

offsets = [(0,0),(-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1),(1,1)]
alignments={r['name']:r['offset'] for r in json.loads((root.parent/'alignment.json').read_text())}
byname={r['name']:r for r in records}

def category(r):
    if r['category']=='terrain':
        parts=r['name'].split('-'); family,style=parts[0],int(parts[2])
        return 'organic' if family in ('xmas','holiday') or (family=='lemmings' and style in (0,1,4)) or (family=='ohno' and style in (1,2)) else 'architectural'
    return {'object':'mechanical','trap':'mechanical','sprite':'sprite','liquid':'liquid'}[r['category']]

def boundaries(key):
    cells=[(key>>(i*4))&15 for i in range(9)]
    center=sum((c==1)<<i for i,c in enumerate(cells))
    opaque=sum((c!=0)<<i for i,c in enumerate(cells))
    for candidate in sorted(set(cells)-{0,1}):
        mask=sum((c==candidate)<<i for i,c in enumerate(cells))
        first=cells.index(candidate)
        brighter=(key>>(36+first))&1
        yield candidate,center|(mask<<9)|(opaque<<18)|(brighter<<27)|(((key>>46)&7)<<28)

def predict(key,table,borders):
    if key in table:return table[key]
    recipe=0x1111; confidence=0
    for candidate,signature in boundaries(key):
        value=borders.get(signature,0)
        if value>>4>confidence:
            confidence=value>>4
            recipe=sum((candidate if value&(1<<i) else 1)<<(i*4) for i in range(4))
    return recipe

def samples(r):
    d,m=read(r,'dos'),read(r,'mac')
    h,w=d.shape[:2]
    if r['category']=='sprite':
        first=r['name'].rsplit('-',1)[0]+'-0'
        ox,oy=alignments[first]
        ox+=r['mac']['x']-byname[first]['mac']['x']
        oy+=r['mac']['y']-byname[first]['mac']['y']
    else: ox,oy=r['mac']['x'],r['mac']['y']
    n=d.repeat(2,0).repeat(2,1)
    canvas=np.zeros_like(n)
    x0,y0=max(0,ox),max(0,oy); x1,y1=min(w*2,ox+m.shape[1]),min(h*2,oy+m.shape[0])
    if x1<=x0 or y1<=y0:return
    canvas[y0:y1,x0:x1]=m[y0-oy:y1-oy,x0-ox:x1-ox]
    # Do not train mismatched sprites or animation phases on empty canvas areas.
    a=n[...,3]!=0; b=canvas[...,3]!=0
    if r['category']=='sprite' and (a&b).sum()/max(1,(a|b).sum())<0.70:return
    colors=np.unique(d[d[...,3]!=0,:3],axis=0).astype(np.int32)
    if not len(colors): return
    # Quantisation is a measurement step only. Runtime output uses source colours.
    extra=np.array([[255,170,34],[102,0,17]],np.int32) if r['category']=='sprite' else np.empty((0,3),np.int32)
    candidates=np.concatenate((colors,extra))
    q=np.zeros((h*2,w*2),np.int32)
    for y in range(h*2):
        delta=canvas[y,:,None,:3].astype(np.int32)-candidates
        q[y]=np.argmin((delta*delta).sum(axis=2),axis=1)+1
    ids=np.zeros((h,w),np.int32)
    lookup={tuple(c):i+1 for i,c in enumerate(colors)}
    for y in range(h):
        for x in range(w):
            if d[y,x,3]:ids[y,x]=lookup[tuple(d[y,x,:3])]
    padded=np.pad(ids,1)
    for y in range(h):
        for x in range(w):
            if not ids[y,x] or not np.all(canvas[y*2:y*2+2,x*2:x*2+2,3]==255):continue
            local=[int(padded[y+1+dy,x+1+dx]) for dx,dy in offsets]
            unique=[0]; signature=0
            red,green,blue=map(int,colors[local[0]-1])
            if max(red,green,blue)-min(red,green,blue)<24: hue=0
            elif red>=green and red>=blue: hue=1 if green<=blue else 2
            elif green>=blue: hue=3 if red>=blue else 4
            else: hue=5 if green>=red else 6
            signature |= hue<<46
            for i,c in enumerate(local):
                if c not in unique: unique.append(c)
                signature |= unique.index(c) << (i*4)
                if c and int(colors[c-1] @ [3,6,1]) > int(colors[local[0]-1] @ [3,6,1]):
                    signature |= 1 << (36+i)
            target=q[y*2:y*2+2,x*2:x*2+2].ravel().tolist()
            if r['category']=='sprite':
                red,green,blue=map(int,colors[local[0]-1])
                skin=red>=200 and green>=160 and blue>=160 and red>green+15 and abs(green-blue)<24
                if skin:signature |= 1<<45
                if any(c>len(colors) for c in target) and not skin:continue
                target=[10+c-len(colors)-1 if c>len(colors) else unique.index(c) if c in unique else 15 for c in target]
                if 15 in target:continue
                packed=sum(c << (i*4) for i,c in enumerate(target))
                yield signature,packed
                continue
            if any(c not in unique for c in target):continue
            packed=sum(unique.index(c) << (i*4) for i,c in enumerate(target))
            yield signature,packed

def texture_samples(r):
    if category(r)!='organic' or r['category']!='terrain':return
    d,m=read(r,'dos'),read(r,'mac');h,w=d.shape[:2]
    ox,oy=r['mac']['x'],r['mac']['y']
    colors=np.unique(d[d[...,3]!=0,:3],axis=0).astype(np.int32)
    ramp={}
    def hue(c):
        r,g,b=map(int,c)
        if max(r,g,b)-min(r,g,b)<24:return 0
        if r>=g and r>=b:return 1 if g<=b else 2
        if g>=b:return 3 if r>=b else 4
        return 5 if g>=r else 6
    for c in colors:
        light=int(c@[3,6,1]);same=[p for p in colors if int(p.sum())>0]
        up=sorted([p for p in same if int(p@[3,6,1])>light],key=lambda p:int(((p-c)**2).sum()))
        down=sorted([p for p in same if int(p@[3,6,1])<light],key=lambda p:int(((p-c)**2).sum()))
        ramp[tuple(c)]=(up[0] if up else c,down[0] if down else c)
    for y in range(1,h-1):
        for x in range(1,w-1):
            local=d[y-1:y+2,x-1:x+2]
            if not np.all(local[...,3]==255):continue
            count=len(np.unique(local[...,:3].reshape(-1,3),axis=0))
            if count<3:continue
            c=d[y,x,:3].astype(np.int32);lum=int(c@[3,6,1]);key=0
            for i,(dx,dy) in enumerate([(0,-1),(-1,0),(1,0),(0,1)]):
                value=int(d[y+dy,x+dx,:3].astype(np.int32)@[3,6,1])
                key|=(0 if value==lum else 1 if value>lum else 2)<<(i*2)
            key|=min(5,count)<<8;key|=hue(c)<<11
            mx,my=x*2-ox,y*2-oy
            if mx<0 or my<0 or mx+2>m.shape[1] or my+2>m.shape[0]:continue
            quad=m[my:my+2,mx:mx+2]
            if not np.all(quad[...,3]==255):continue
            up,down=ramp[tuple(c)]
            candidates=np.array([c,up,down])
            value=0
            for i,pixel in enumerate(quad[...,:3].reshape(-1,3)):
                delta=colors-pixel.astype(np.int32)
                authored=colors[np.argmin((delta*delta).sum(axis=1))]
                matches=np.where(np.all(candidates==authored,axis=1))[0]
                if not len(matches):break
                value|=int(matches[0])<<(i*2)
            else:yield key,value

def measured_brush():
    """A small tone stencil measured from an opaque patch of Mac dirt.

    Retain at least two source-colour pixels in every block. This transfers
    mark spacing, not the copyrighted terrain silhouette or its palette.
    """
    r=byname['lemmings-terrain-0-0'];d,m=read(r,'dos'),read(r,'mac')
    ox,oy=r['mac']['x'],r['mac']['y'];best=None
    for y in range(1,d.shape[0]-4):
        for x in range(1,d.shape[1]-4):
            if not np.all(d[y:y+4,x:x+4,3]==255):continue
            mx,my=x*2-ox,y*2-oy
            if mx<0 or my<0 or mx+8>m.shape[1] or my+8>m.shape[0]:continue
            patch=m[my:my+8,mx:mx+8]
            if not np.all(patch[...,3]==255):continue
            marks=np.zeros((8,8),np.uint8)
            for py in range(4):
                for px in range(4):
                    center=d[y+py,x+px,:3].astype(np.int32)
                    quad=patch[py*2:py*2+2,px*2:px*2+2,:3].astype(np.int32)
                    delta=(quad-center)@[3,6,1]
                    candidates=sorted([(abs(int(delta[dy,dx])),dy,dx) for dy in range(2) for dx in range(2)],reverse=True)
                    for strength,dy,dx in candidates[:2]:
                        if strength>100:marks[py*2+dy,px*2+dx]=1 if delta[dy,dx]>0 else 2
            high=int((marks==1).sum());low=int((marks==2).sum())
            score=abs(high-12)+abs(low-12)
            if best is None or score<best[0]:best=(score,x,y,marks)
    _,x,y,marks=best
    return marks.ravel().tolist(),dict(reference=r['name'],source_x=x,source_y=y,light_marks=int((marks==1).sum()),shadow_marks=int((marks==2).sum()))

if __name__=='__main__':
    tables=collections.defaultdict(lambda:collections.defaultdict(collections.Counter))
    borders=collections.defaultdict(lambda:collections.defaultdict(collections.Counter))
    support=collections.defaultdict(lambda:collections.defaultdict(lambda:collections.defaultdict(set)))
    boundary_support=collections.defaultdict(lambda:collections.defaultdict(lambda:collections.defaultdict(set)))
    textures=collections.defaultdict(collections.Counter)
    texture_validation=[]
    validation=[]; seen=set(); totals=collections.Counter()
    for r in records:
        # Xmas and Holiday duplicate references must not inflate confidence.
        fingerprint=hashlib.sha256(read(r,'dos').tobytes()+read(r,'mac').tobytes()).digest()
        if fingerprint in seen:continue
        seen.add(fingerprint)
        cat=category(r)
        # Split by asset/sequence, so adjacent frames cannot leak into validation.
        group=r['name'].rsplit('-',1)[0] if r['category']!='terrain' else r['name']
        heldout=int(hashlib.sha256(group.encode()).hexdigest()[:8],16)%5==0
        for key,value in texture_samples(r):
            if heldout:texture_validation.append((key,value))
            else:textures[key][value]+=1
        for signature,target in samples(r):
            totals[cat]+=1
            if heldout:validation.append((cat,signature,target))
            else:
                tables[cat][signature][target]+=1
                support[cat][signature][target].add(group)
                for candidate,key in boundaries(signature):
                    mask=sum((((target>>(i*4))&15)==candidate)<<i for i in range(4))
                    borders[cat][key][mask]+=1
                    boundary_support[cat][key][mask].add(group)
    rules={}; boundary_rules={}; stats={}
    for cat,table in sorted(tables.items()):
        chosen={}
        for key,c in table.items():
            value,count=sorted(c.items(),key=lambda p:(-p[1],p[0]))[0]
            # Preserve ambiguous shapes and straight flat fills.
            retained=sum((value>>(i*4))&15==1 for i in range(4))
            threshold=0.92 if cat in ('mechanical','liquid') else 0.70
            supported=cat not in ('mechanical','liquid') or len(support[cat][key][value])>=2
            if supported and count>=3 and count/sum(c.values())>=threshold and (1<=retained<=3 or (cat=='sprite' and key&(1<<45) and value!=0x1111)):
                chosen[key]=value
        rules[cat]=chosen
        boundary_rules[cat]={}
        for key,c in borders[cat].items():
            value,count=sorted(c.items(),key=lambda p:(-p[1],p[0]))[0]
            confidence=count/sum(c.values())
            threshold={'sprite':.65,'organic':.8,'architectural':.85,'mechanical':.95,'liquid':.95}[cat]
            supported=cat not in ('mechanical','liquid') or len(boundary_support[cat][key][value])>=2
            if supported and 0<value<15 and count>=8 and confidence>=threshold:
                boundary_rules[cat][key]=value|(int(confidence*255)<<4)
        subset=[(key,target) for c,key,target in validation if c==cat]
        errors=sum(sum(((predict(k,chosen,boundary_rules[cat])>>(i*4))&15)!=((t>>(i*4))&15) for i in range(4)) for k,t in subset)
        baseline=sum(sum(1!=((t>>(i*4))&15) for i in range(4)) for k,t in subset)
        stats[cat]=dict(samples=totals[cat],rules=len(chosen),boundary_rules=len(boundary_rules[cat]),heldout_blocks=len(subset),
            heldout_pixel_errors=errors,nearest_pixel_errors=baseline)
    output=pathlib.Path(sys.argv[2])
    texture_rules={}
    for key,c in textures.items():
        changed=sum(n for v,n in c.items() if v!=0)
        possible=[(v,n) for v,n in c.items() if sum(((v>>(i*2))&3)!=0 for i in range(4)) in (1,2,3)]
        if possible and changed>=8 and changed/sum(c.values())>=.45:
            value,count=sorted(possible,key=lambda p:(-p[1],p[0]))[0]
            if count>=3:texture_rules[key]=value
    stats['organic_texture']=dict(rules=len(texture_rules),development_blocks=len(texture_validation),
        changed_development_blocks=sum(k in texture_rules for k,v in texture_validation))
    brush,brush_evidence=measured_brush()
    stats['organic_brush']=brush_evidence
    lines=['// Generated by Tools/SequelMacArtwork/learn.py. Do not edit.',
        '// Nibbles select local colours; keys encode a 3x3 equality pattern.',
        'enum Lemmings2MacRuleTables {',
        '    static let tables: [SequelMacCategory: [UInt64: UInt16]] = [']
    for cat,table in rules.items():
        lines.append('        .'+cat+': decode("""')
        lines.extend(f'{key:x}:{value:x}' for key,value in sorted(table.items()))
        lines.append('        """),')
    lines+=['    ]','    static let boundaries: [SequelMacCategory: [UInt64: UInt16]] = [']
    for cat,table in boundary_rules.items():
        lines.append('        .'+cat+': decode("""')
        lines.extend(f'{key:x}:{value:x}' for key,value in sorted(table.items()))
        lines.append('        """),')
    lines+=['    ]','    static let texture = decode("""']
    lines.extend(f'{key:x}:{value:x}' for key,value in sorted(texture_rules.items()))
    lines+=['    """)','    static let organicBrush: [UInt8] = ['+','.join(map(str,brush))+']',
        '    private static func decode(_ text: String) -> [UInt64: UInt16] {',
        '        Dictionary(uniqueKeysWithValues: text.split(whereSeparator: \\.isWhitespace).map { row in',
        '            let pair = row.split(separator: ":")',
        '            return (UInt64(pair[0], radix: 16)!, UInt16(pair[1], radix: 16)!)',
        '        })','    }','}']
    # Swift multiline literals require content indentation to match the delimiter.
    lines=[('        '+line if line and line[0] in '0123456789abcdef' and ':' in line and not line.startswith('enum') else line) for line in lines]
    output.write_text('\n'.join(lines)+'\n')
    (root.parent/'rule-measurements.json').write_text(json.dumps(stats,indent=2))
    print(json.dumps(stats,indent=2))
