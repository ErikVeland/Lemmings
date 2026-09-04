#!/usr/bin/env python3
"""Extract supplied IPF disks. Pass a locally built CAPS/SPS library path.

This is a one-time asset import, not part of a normal app build. The source
images and extracted commercial data remain in the ignored Sources/Ports tree.
CAPS ABI and MFM formats follow Keir Fraser's public-domain disk utilities.
ByteKiller decoding follows Ancient (BSD-2-Clause); see THIRD_PARTY_NOTICES.md.
"""
import ctypes as ct
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
PORTS = ROOT/'Sources/Ports'

class Track(ct.Structure):
    _layout_ = 'ms'
    _pack_ = 1
    _fields_ = [('type',ct.c_uint),('cylinder',ct.c_uint),('head',ct.c_uint),
                ('sectorcnt',ct.c_uint),('sectorsize',ct.c_uint),
                ('trackbuf',ct.POINTER(ct.c_ubyte)),('tracklen',ct.c_uint),
                ('timelen',ct.c_uint),('timebuf',ct.POINTER(ct.c_uint)),
                ('overlap',ct.c_int),('startbit',ct.c_uint),('wseed',ct.c_uint),('weakcnt',ct.c_uint)]

def unpack(data):
    if len(data) < 12 or len(data)%4:
        raise ValueError('Invalid ByteKiller size')
    words = list(struct.unpack('>'+str(len(data)//4)+'I',data))
    size = words.pop(); check = words.pop()
    if not 0 < size < 2_000_000: raise ValueError('Invalid ByteKiller output size')
    for value in words: check ^= value
    if check: raise ValueError('ByteKiller checksum mismatch')
    value = words.pop(); bits = value.bit_length()-1
    if bits < 0: raise ValueError('Missing ByteKiller anchor bit')
    value &= (1<<bits)-1
    def read(count):
        nonlocal bits,value
        result = 0
        for _ in range(count):
            if bits == 0: value = words.pop(); bits = 32
            result = (result<<1)|(value&1); value >>= 1; bits -= 1
        return result
    out = bytearray(size); pos = size
    while pos:
        if read(1) == 0:
            if read(1) == 0: count = read(3)+1; distance = 0
            else: count = 2; distance = read(8)
        else:
            code = read(2)
            if code == 3: count = read(8)+9; distance = 0
            elif code == 2: count = read(8)+1; distance = read(12)
            else: count = code+3; distance = read(code+9)
        if count > pos: raise ValueError('ByteKiller output overrun')
        for _ in range(count):
            pos -= 1
            out[pos] = out[pos+distance] if distance else read(8)
    return bytes(out)

def mfm(data):
    half = len(data)//2
    return bytes(((a&0x55)<<1)|(b&0x55) for a,b in zip(data[:half],data[half:]))

def checksum(data):
    result = 0
    for value in struct.unpack('>'+str(len(data)//4)+'I',data): result ^= value
    return (result^(result>>1))&0x55555555

def bits_bytes(bits):
    if len(bits)%8: raise ValueError('Incomplete track bytes')
    return int(bits,2).to_bytes(len(bits)//8,'big')

def tracks(lib, path, dos=False):
    iid = lib.CAPSAddImage()
    if lib.CAPSLockImage(iid,str(path).encode()): raise ValueError(f'Cannot open {path}')
    output = bytearray(901120 if dos else 160*6144)
    signature = ''.join(f'{v:08b}' for v in bytes.fromhex('44894489' if dos else '4489552aaaaa'))
    try:
        for number in range(0 if dos else 2,160):
            info = Track(2)
            flags = (1<<2)|(1<<8)|(1<<9)|(1<<11)|(1<<12)|(1<<13)
            if lib.CAPSLockTrack(ct.byref(info),iid,number//2,number%2,flags) or not info.trackbuf:
                raise ValueError(f'Missing track {number}')
            raw = bytes(info.trackbuf[:(info.tracklen+7)//8])
            bits = ''.join(f'{v:08b}' for v in raw)[:info.tracklen]
            bits += bits
            found = set(); pos = -1
            while True:
                pos = bits.find(signature,pos+1)
                if pos < 0 or pos >= info.tracklen: break
                if dos:
                    sec = bits_bytes(bits[pos:pos+1084*8])
                    header = mfm(sec[4:12]); data = mfm(sec[60:1084])
                    if header[0] != 255 or header[1] != number or header[2] >= 11: continue
                    if int.from_bytes(mfm(sec[44:52]),'big') != checksum(header+mfm(sec[12:44])): continue
                    if int.from_bytes(mfm(sec[52:60]),'big') != checksum(data): continue
                    start = (number*11+header[2])*512
                    output[start:start+512] = data; found.add(header[2])
                else:
                    raw = bits_bytes(bits[pos+48:pos+48+6*513*32])
                    decoded = b''.join(mfm(raw[i:i+4]) for i in range(0,len(raw),4))
                    for sector in range(6):
                        sec = decoded[sector*1026:(sector+1)*1026]; data = sec[2:]
                        if sum(struct.unpack('>512H',data))&65535 != int.from_bytes(sec[:2],'big'): continue
                        start = number*6144+sector*1024
                        output[start:start+1024] = data; found.add(sector)
            if len(found) != (11 if dos else 6): raise ValueError(f'Bad checksum on track {number}')
    finally:
        lib.CAPSUnlockImage(iid); lib.CAPSRemImage(iid)
    return bytes(output)

def custom_files(data):
    offset = 0; files = {}
    for pos in range(0x3000,0x4000,16):
        record = data[pos:pos+16]
        if record[0] == 255: break
        name = record[:12].split(b'\0')[0].decode().lower()
        size = int.from_bytes(record[12:],'big')
        files[name] = data[offset:offset+size]
        offset += (size+1023)//1024*1024
    return files

def adf_files(data):
    def number(block,offset): return int.from_bytes(data[block*512+offset:block*512+offset+4],'big')
    def content(block):
        size = number(block,324); result = bytearray(); seen = set()
        first = number(block,16)
        while first:
            if first in seen: raise ValueError('Cyclic ADF file')
            seen.add(first)
            count = number(first,12)
            result += data[first*512+24:first*512+24+count]
            first = number(first,16)
        if len(result) != size: raise ValueError('Truncated ADF file')
        return bytes(result)
    files = {}; visited = set()
    def directory(block):
        if block in visited: raise ValueError('Cyclic ADF directory')
        visited.add(block)
        for bucket in range(72):
            item = number(block,24+bucket*4); chain = set()
            while item:
                if item in chain: raise ValueError('Cyclic ADF bucket')
                chain.add(item)
                pos = item*512+432; name = data[pos+1:pos+1+data[pos]].decode('latin1').lower()
                kind = number(item,508)
                if kind == 2: directory(item)
                elif kind == 0xfffffffd: files[name] = content(item)
                item = number(item,496)
    if data[:4] != b'DOS\0': raise ValueError('Expected Amiga OFS disk')
    directory(880)
    return files

def main():
    lib = ct.CDLL(sys.argv[1])
    if lib.CAPSInit(): raise ValueError('Cannot initialize CAPS library')
    sources = [('lemmings','lemmings_amiga_0132/Lemmings_Disk2.ipf'),
               ('ohno','OhNo!MoreLemmings.ipf'),('holiday','HolidayLemmings1994.ipf')]
    output = PORTS/'amiga_extracted'; provenance = {}
    for family,name in sources:
        source = PORTS/name
        data = tracks(lib,source,dos=family=='holiday')
        files = adf_files(data) if family=='holiday' else custom_files(data)
        folder = output/family; folder.mkdir(parents=True,exist_ok=True)
        for key,value in files.items():
            if key.startswith(('ground','objects','special','leveldata','panel')):
                (folder/key).write_bytes(unpack(value))
        provenance[name] = hashlib.sha256(source.read_bytes()).hexdigest()
    name = 'lemmings_amiga_0132/Lemmings_Disk1.ipf'; source = PORTS/name
    code = custom_files(tracks(lib,source))['code']
    (output/'lemmings/code').write_bytes(unpack(code))
    provenance[name] = hashlib.sha256(source.read_bytes()).hexdigest()
    (output/'sources.json').write_text(json.dumps(provenance,indent=2)+'\n')
    lib.CAPSExit()
    print('Imported original Amiga artwork:',output)

if __name__ == '__main__': main()
