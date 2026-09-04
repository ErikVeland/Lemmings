#!/usr/bin/env python3
"""Export original Amiga planar artwork into the shared 2x RGBA frame banks.

Input is the local, extracted disk data. No downloads occur during app builds.
"""
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Sources/Ports/amiga_extracted'

def word(data, offset):
    return struct.unpack_from('>H', data, offset)[0]

def long(data, offset):
    return struct.unpack_from('>I', data, offset)[0]

def planar(data, width, height, depth, palette, offset=0, mask=None):
    stride = ((width + 15) // 16) * 2
    size = stride * height
    if offset + size * depth > len(data) or (mask is not None and mask + size > len(data)):
        raise ValueError('Truncated Amiga bitplanes')
    pixels = bytearray(width * height * 4)
    for y in range(height):
        for x in range(width):
            bit = 7 - x % 8
            pos = y * stride + x // 8
            value = sum(((data[offset + plane * size + pos] >> bit) & 1) << plane for plane in range(depth))
            opaque = (data[mask + pos] >> bit) & 1 if mask is not None else 1
            pixels[(y * width + x) * 4:(y * width + x + 1) * 4] = bytes((*palette[value], 255 * opaque))
    return bytes(pixels)

def ilbm(data):
    if data[:4] != b'FORM' or data[8:12] != b'ILBM':
        raise ValueError('Expected ILBM artwork')
    end = long(data, 4) + 8
    chunks = {}; pos = 12
    while pos < end:
        count = long(data, pos + 4)
        chunks[data[pos:pos+4]] = data[pos+8:pos+8+count]
        pos += 8 + count + (count & 1)
    header = chunks[b'BMHD']
    width, height = word(header, 0), word(header, 2)
    depth, masking, compression = header[8:11]
    raw = chunks[b'BODY']; decoded = bytearray(); pos = 0
    if compression:
        while pos < len(raw):
            code = raw[pos]; pos += 1
            if code < 128:
                decoded += raw[pos:pos+code+1]; pos += code+1
            elif code > 128:
                decoded += raw[pos:pos+1] * (257-code); pos += 1
    else:
        decoded = raw
    stride = ((width + 15) // 16) * 2
    planes = depth + (masking == 1)
    if len(decoded) != stride * height * planes:
        raise ValueError('Incorrect ILBM pixel length')
    # ILBM interleaves planes by row; the game bitmaps store whole planes.
    reordered = b''.join(decoded[(y*planes+p)*stride:(y*planes+p+1)*stride]
                         for p in range(planes) for y in range(height))
    palette = list(zip(*[iter(chunks[b'CMAP'])]*3))
    return width, height, planar(reordered, width, height, depth, palette,
                                mask=stride*height*depth if masking == 1 else None)

def doubled(width, height, pixels):
    output = bytearray()
    for y in range(height):
        row = b''.join(pixels[(y*width+x)*4:(y*width+x+1)*4]*2 for x in range(width))
        output += row * 2
    return width*2, height*2, bytes(output)

# Authored animation runs in the original Amiga Code file. The shared bank IDs
# match the Macintosh pose map, including gaps for construction/mask images.
ANIMATIONS = [
    (0,52038,8,16,10,2),(8,52518,1,16,10,2),(9,52578,8,16,10,2),(17,53058,1,16,10,2),
    (18,53118,4,16,10,2),(22,53358,4,16,10,2),(26,53598,16,16,14,3),
    (43,55390,8,16,12,2),(51,55966,8,16,12,2),(59,56542,8,16,12,2),(67,57118,8,16,12,2),
    (75,57694,1,32,32,3),(77,58206,16,16,13,3),(94,59870,16,16,13,3),
    (111,61534,16,16,10,2),(127,62494,16,16,10,2),(143,63454,32,16,10,3),
    (179,66014,32,16,10,3),(215,68574,4,16,16,3),(219,69086,4,16,16,3),
    (223,69598,4,16,16,3),(227,70110,4,16,16,3),(231,70622,24,16,13,3),
    (257,73118,24,16,13,3),(283,75614,16,16,10,2),(299,76574,8,16,13,2),
    (307,77198,14,16,14,4),(321,79158,8,16,10,2),(329,79638,8,16,10,2),
    (337,80118,16,16,10,2)]

def export(family, directory, styles, output):
    output.mkdir(parents=True, exist_ok=True)
    tables = (directory/'leveldata').read_bytes()
    banks = {}; objects = {}
    def save(bank, index, width, height, pixels):
        width, height, pixels = doubled(width, height, pixels)
        name = f'{bank}-{index}.rgba'
        (output/name).write_bytes(pixels)
        frames = banks.setdefault(str(bank), [])
        while len(frames) <= index: frames.append(None)
        frames[index] = dict(x=0,y=0,width=width,height=height,file=name)
    for style, disk_style in styles:
        base = disk_style * 1424
        colors = [word(tables, base+i*2) for i in range(16)]
        palette = [tuple(((c>>shift)&15)*17 for shift in (8,4,0)) for c in colors]
        ground = (directory/f'ground{disk_style+1}').read_bytes()
        obj = (directory/f'objects{disk_style+1}').read_bytes()
        terrain_base = long(tables, base+660)
        object_base = long(tables, base+112+34+26)
        for index in range(64):
            pos = base+656+index*12
            width,height = word(tables,pos),word(tables,pos+2)
            if not width or not height or width == 65535: continue
            pixels = planar(ground,width,height,3,palette[8:],long(tables,pos+4)-terrain_base,long(tables,pos+8)-terrain_base)
            save(1500+style,index,width,height,pixels)
        definitions = []; frame_base = 0
        for index in range(16):
            pos = base+112+index*34
            first,count,width,height,size,mask = [word(tables,pos+i*2) for i in range(1,7)]
            definitions.append(dict(first=first,count=count,base=frame_base))
            if not count: continue
            start = long(tables,pos+26)-object_base
            for frame in range(count):
                offset = start+size*frame
                pixels = planar(obj,width,height,4,palette,offset,offset+mask)
                save(1600+style,frame_base+frame,width,height,pixels)
            frame_base += count
        objects[str(style)] = definitions
    # All classic Amiga titles use the original animation shapes. Holiday uses
    # its own red-clothing palette; the animation source remains the 1991 disk.
    code = (SOURCE/'lemmings/code').read_bytes()
    colors = [word(tables,i*2) for i in range(16)]
    palette = [tuple(((c>>shift)&15)*17 for shift in (8,4,0)) for c in colors]
    for bank_index,offset,count,width,height,depth in ANIMATIONS:
        plane_size = width//8*height
        for frame in range(count):
            start=offset+frame*plane_size*(depth+1)
            pixels=planar(code,width,height,depth,palette,start,start+plane_size*depth)
            save(1400,bank_index+frame,width,height,pixels)
    if family == 'lemmings':
        for index in range(4):
            width,height,pixels=ilbm((directory/f'special{index}').read_bytes())
            save(1700+index,0,width,160,pixels[:width*160*4])
    (output/'manifest.json').write_text(json.dumps(dict(version=3,banks=banks,objects=objects)))
    print(f'Amiga {family}: {sum(len(v) for v in banks.values())} frame slots')

def main():
    output = Path(sys.argv[1])
    export('lemmings',SOURCE/'lemmings',[(i,i) for i in range(5)],output/'lemmings')
    export('ohno',SOURCE/'ohno',[(i,i) for i in range(4)],output/'ohno')
    export('xmas',SOURCE/'holiday',[(0,0),(2,2)],output/'xmas')
    export('holiday',SOURCE/'holiday',[(2,2)],output/'holiday')

if __name__ == '__main__': main()
