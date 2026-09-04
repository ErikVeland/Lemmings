#!/usr/bin/env python3
"""Decode supplied Macintosh artwork into portable RGBA banks for the app.

SHPD and Presage LZSS formats follow resource_dasm (MIT; see notices).
No source artwork is fetched from the network.
"""
import struct,pathlib,json,subprocess,sys,shutil,tempfile
U16=lambda d,o:struct.unpack_from('>H',d,o)[0]
U32=lambda d,o:struct.unpack_from('>I',d,o)[0]
def resources(d):
 out=[]; base=U32(d,0); m=U32(d,4);t=m+U16(d,m+24);n=m+U16(d,m+26)
 for i in range((U16(d,t)+1)&65535):
  e=t+2+i*8; typ=d[e:e+4].decode('mac_roman'); r=t+U16(d,e+6)
  for j in range(U16(d,e+4)+1):
   q=r+j*12;id=U16(d,q);no=U16(d,q+2);p=base+(U32(d,q+4)&0xffffff);name='' if no==65535 else d[n+no+1:n+no+1+d[n+no]].decode('mac_roman')
   out.append((typ,id,name,d[p+4:p+4+U32(d,p)]))
 return out
def hfs(path,out):
 d=pathlib.Path(path).read_bytes();m=1024;bs=U32(d,m+20);first=U16(d,m+28)*512
 def fork(length,ex):
  return b''.join(d[first+U16(d,ex+i*4)*bs:first+(U16(d,ex+i*4)+U16(d,ex+i*4+2))*bs] for i in range(3))[:length]
 c=fork(U32(d,m+146),m+150);out=pathlib.Path(out);out.mkdir(parents=True,exist_ok=True)
 for b in range(0,len(c)-511,512):
  if c[b+8]!=255:continue
  for j in range(U16(c,b+10)):
   p=b+U16(c,b+510-j*2);n=c[p+6];name=c[p+7:p+7+n].decode('mac_roman').replace('/','_');q=p+1+c[p];q+=(q%2)
   if c[q]!=2:continue
   for tag,lo,ex in [('data',26,74),('rsrc',36,86)]:
    length=U32(c,q+lo)
    if length:
     result=b''.join(d[first+U16(c,q+ex+i*4)*bs:first+(U16(c,q+ex+i*4)+U16(c,q+ex+i*4+2))*bs] for i in range(3))[:length]
     (out/(name+'.'+tag)).write_bytes(result)
def unpack(d,size):
 out=bytearray();p=0
 while len(out)<size:
  flags=d[p];p+=1
  for i in range(8):
   if len(out)>=size:break
   if flags&(1<<i):
    a=U16(d,p);p+=2;dist=(a&4095)+1
    for _ in range((a>>12)+3):out.append(out[-dist])
   else:out.append(d[p]);p+=1
 assert len(out)==size
 return out

def png_rgba(path):
    dimensions=subprocess.check_output(['magick',str(path),'-format','%w %h','info:'],text=True).split()
    width,height=map(int,dimensions)
    rgba=subprocess.check_output(['magick',str(path),'-alpha','on','-depth','8','rgba:-'])
    assert len(rgba)==width*height*4
    return width,height,rgba

def decode_bank(bank,palette,version):
    end=U32(bank,0)
    if not end:return None
    if end%4 or end>len(bank):raise ValueError('Invalid SHPD frame table')
    frames=[]
    for slot in range(end//4):
        offset=U32(bank,slot*4)
        if not offset:frames.append(None);continue
        offset+=4 if version==2 else 0
        ox,oy,w,h=struct.unpack_from('>hhHH',bank,offset)
        if w*h>4_000_000:raise ValueError('Invalid SHPD dimensions')
        if not w or not h:frames.append(None);continue
        pixels=bytearray(w*h*4);dest=0;pos=offset+8
        while dest<w*h:
            cmd=bank[pos];pos+=1;count=(cmd&127)+1
            if dest+count>w*h:raise ValueError('SHPD run exceeds image')
            if not cmd&128:
                for value in bank[pos:pos+count]:
                    pixels[dest*4:dest*4+4]=bytes(palette[value]);dest+=1
                pos+=count
            else:dest+=count
        frames.append((ox,oy,w,h,pixels))
    return frames

def export(source,app,output,version):
    output.mkdir(parents=True,exist_ok=True)
    application=resources((source/(app+'.rsrc')).read_bytes())
    clut=next(d for t,i,n,d in application if t=='clut' and i==1000)
    palette=[(0,0,0,255)]*256
    for off in range(8,len(clut),8):
        index,r,g,b=struct.unpack_from('>HHHH',clut,off)
        palette[index]=(r>>8,g>>8,b>>8,255)
    graphics=(source/'Graphics.data').read_bytes(); banks={}; names={}
    for typ,bank_id,name,record in resources((source/'Graphics.rsrc').read_bytes()):
        if typ!='SHPD':continue
        offset,csize,size=struct.unpack('>III',record)
        bank=unpack(graphics[offset:offset+csize],size) if csize else graphics[offset:offset+size]
        assert len(bank)==size
        frames=decode_bank(bank,palette,version)
        if frames is None:
            with tempfile.TemporaryDirectory() as temp:
                pict=pathlib.Path(temp)/'image.pict';pict.write_bytes(bytes(512)+bank)
                w,h,rgba=png_rgba(pict);frames=[(0,0,w,h,rgba)]
        bank_meta=[]
        for index,frame in enumerate(frames):
            if frame is None:bank_meta.append(None);continue
            ox,oy,w,h,rgba=frame;filename=f'{bank_id}-{index}.rgba'
            (output/filename).write_bytes(rgba)
            bank_meta.append(dict(x=ox,y=oy,width=w,height=h,file=filename))
        banks[str(bank_id)]=bank_meta;names[str(bank_id)]=name
    definitions={}
    for typ,style,name,data in resources((source/'Levels.rsrc').read_bytes()):
        if typ=='OBJD':
            definitions[str(style)]=[dict(first=U16(data,p+2),count=U16(data,p+4),base=U16(data,p+6)) for p in range(0,len(data),26)]
    manifest=dict(version=version,banks=banks,names=names,objects=definitions)
    (output/'manifest.json').write_text(json.dumps(manifest,separators=(',',':')))
    print(f'Mac artwork: {output.name}, {sum(len(x) for x in banks.values())} frames')

def copy_forks(source,dest,app):
    dest.mkdir(parents=True,exist_ok=True)
    for name in ['Graphics','Levels',app]:
        path=source/name
        if name=='Graphics':(dest/'Graphics.data').write_bytes(path.read_bytes())
        (dest/(name+'.rsrc')).write_bytes(pathlib.Path(str(path)+'/..namedfork/rsrc').read_bytes())

def prepare(project,output):
    build=project/'.build/mac-artwork';build.mkdir(parents=True,exist_ok=True)
    archive=project/'Sources/Ports/LemmingsONML.sit_.bin'
    unpacked=build/'archive'
    if not (unpacked/'Lemmings:ONML').exists():
        subprocess.run(['unar','-q','-f','-o',str(unpacked),str(archive)],check=True)
    original=build/'original'
    hfs(project/'Sources/Ports/lemmings_1_5_2/Lemmings_1_5_2.dsk',original)
    onml=build/'ohno'
    for disk in (unpacked/'Lemmings:ONML/Oh No! More Lemmings/Disk Images').glob('*.img'):hfs(disk,onml)
    installer=project/'.build/holiday-assets/Holiday Lemmings 1994 Installer'
    if not (installer/'Graphics').exists():
        subprocess.run(['unar','-q','-f','-o',str(installer.parent),
            str(project/'Sources/Ports/mac_extracted/Holiday_Lem93_94/Holiday Lemmings 1994 Installer')],check=True)
    holiday=build/'holiday' 
    copy_forks(installer,holiday,'Holiday Lemmings 1994')
    xmas=build/'xmas'
    copy_forks(project/"Sources/Ports/mac_extracted/Holiday_Lem93_94/Extras/X-Mas Demo '92",xmas,'Xmas Lemmings')
    for name,source,app,version in [('lemmings',original,'Lemmings',1),('ohno',onml,'Oh No! More Lemmings',2),('holiday',holiday,'Holiday Lemmings 1994',2),('xmas',xmas,'Xmas Lemmings',1)]:
        export(source,app,output/name,version)
    # Xmas '92 retains the brick bank used by Xmas '91, but its Levels file
    # contains only the snow definitions. The Holiday installer preserves the
    # matching 104-frame brick object table.
    path=output/'xmas/manifest.json'
    manifest=json.loads(path.read_text())
    holiday_manifest=json.loads((output/'holiday/manifest.json').read_text())
    manifest['objects']['0']=holiday_manifest['objects']['0']
    path.write_text(json.dumps(manifest,separators=(',',':')))

if __name__=='__main__':
    prepare(pathlib.Path(__file__).resolve().parents[2],pathlib.Path(sys.argv[1]).resolve())
