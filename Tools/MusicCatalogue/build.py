#!/usr/bin/env python3
"""Build a track catalogue and a linked browsing hierarchy without moving assets."""
import argparse
import gzip
import json
import os
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CLASSIC_TITLES = dict(zip(
    ['cancan','lemming1','tim2','lemming2','tim8','tim3','tim5','doggie','tim6','lemming3','tim7','tim9','tim1','tim10','tim4','tenlemmings','mountain'],
    ['Can-Can','Lemming 1','Smile if You Love Lemmings','Lemming 2','Dance of the Little Swans','Lend a Helping Hand','Mind the Step','How Much Is That Doggie in the Window','Dance of the Reed Flutes','Lemming 3','Turkish March','London Bridge Is Falling Down','Rainbow Islands','Forest Green','Postcard from Lemmingland','Ten Lemmings','Coming Round the Mountain']))
CLASSIC_TITLES.update({'beasti':'Shadow of the Beast','beastii':'Shadow of the Beast II','menace':'Menace','awesome':'Awesome','intro':'March of the Mods'})
OHNO = ['Very Cute','Wacky','Patronizingly Happy','Much Joviality','Not At All Serious','The Smiling Blues']
TRIBES = ['beach','cavelem','circus','classic','egyptian','highland','medieval','outdoor','polar','shadow','space','sports']
PORTS = {'Archimedes':'archimedes','Lemmings (MP3)':'snes','Lemmings-SMS':'master-system','IBM_PC_AT':'dos-opl2','Tandy_1000':'tandy','Mega Drive, Genesis':'mega-drive','Nintendo_Game_Boy':'game-boy','Atari_Lynx':'lynx','FM_Towns':'fm-towns','NEC_PC-9801':'pc-98','NES':'nes','Sharp_X68000':'x68000','ZX_Spectrum_128':'spectrum','Arcade':'arcade','Lemmings_3D':'dos-opl3'}
PLAYABLE = {'.mod','.m4a','.wav','.mp3','.flac','.aif','.aiff','.aifc','.caf'}
# These filenames are level labels, not composition titles. Keep this mapping
# local to the identified SNES collection, never as global title aliases.
SNES_LEVELS = dict(zip([
    'Just Dig!', 'Only Floaters Can Survive This', 'Tailor-Made For Blockers',
    'Now Use Miners and Climbers', 'You Need Bashers This Time',
    'A Task For Blockers and Bombers', 'Builders Will Help You Here',
    'Not As Complicated As it Looks', 'As Long As You Try Your Best',
    'Smile if You Love Lemmings', 'Keep Your Hair on Mr. Lemming', 'Patience',
    'We All Fall Down', 'Origins and Lemmings', "Don't Let Your Eyes Deceive You",
    "Don't Do Anything Too Hasty", 'Easy When You Know How'], list(CLASSIC_TITLES)[:17]))
COLLECTION_ALIASES = {
    'One Way Or Another': 'lemming2', 'Keep Your Hair On Mr Lemming': 'lemming3',
    "Palcelbel's Cannon": 'lemming1', 'Ten Green Bottles': 'tenlemmings',
    'Professor Mariarti': 'mariarti', 'Can Can': 'cancan',
    'Shadow of the Beast I': 'beasti', 'Rondo Alla Turca': 'tim7'}



def slug(value):
    return re.sub(r'[^a-z0-9]+', '-', value.lower()).strip('-')


def normal(value):
    return re.sub(r'[^a-z0-9]', '', value.lower())


def gd3(path):
    data = path.read_bytes()
    if data[:2] == b'\x1f\x8b': data = gzip.decompress(data)
    if len(data)<0x24 or data[:4]!=b'Vgm ': raise ValueError(f'Invalid VGM: {path}')
    offset = 20 + struct.unpack_from('<I', data, 20)[0]
    if data[offset:offset+4] != b'Gd3 ': return []
    return data[offset+12:offset+12+struct.unpack_from('<I', data, offset+8)[0]].decode('utf-16-le').split('\0')


def classic_key(title):
    n = normal(title)
    for key, name in CLASSIC_TITLES.items():
        if n in {normal(key), normal(name)}: return key
    # Long and numbered names need explicit aliases; never use track-number modulo.
    aliases = [('shadowofthebeastiilevel','beastii'),('shadowofthebeastii','beastii'),('beastii','beastii'),
        ('shadowofthebeastopening','beasti'),('beast','beasti'),('menace','menace'),('awesome','awesome'),
        ('shellbecoming','mountain'),('tenlemmings','tenlemmings'),('cancan','cancan'),
        ('thatdog','doggie'),('howmuchisthatdog','doggie'),('danceofthereed','tim6'),('danceofthetoyflutes','tim6'),
        ('rondoallaturca','tim7'),('tengreenbottles','tenlemmings'),('shadowofthebeasti','beasti'),('rondaallaturca','tim7'),('allaturca','tim7'),('danceofthefourlittleswans','tim8'),
        ('allegromoderato','tim8'),('londonbridge','tim9'),('forestgreen','tim10'),('marchofthemods','intro')]
    for prefix, key in aliases:
        if n.startswith(prefix): return key
    m = re.match(r'^tim\s*(10|[1-9])(?:\b|\s*-)', title.lower())
    return 'tim'+m[1] if m else None


def classify(path, music):
    relative = path.relative_to(music).as_posix()
    folder = relative.split('/')[0]
    title = re.sub(r'^\d+\s*[-. ]\s*', '', path.stem)
    source = path.with_suffix('.vgz')
    if not source.exists(): source = path.with_suffix('.vgm')
    tags = gd3(source) if source.exists() else []
    if tags: title = tags[0]
    port = next((v for k,v in PORTS.items() if k in folder), 'unknown')
    if folder.endswith('_mod') or folder.endswith('_mod_tsyu') or folder.startswith('CoLD SToRAGE'): port = 'amiga'
    game, role, key, confidence = 'classic', 'level', None, 'documented'
    quality, remix = ('native-module' if path.suffix=='.mod' else 'chip-render' if tags else 'lossy-source' if path.suffix=='.mp3' else 'unverified-source'), 'original'
    source_notes = tags[10] if len(tags)>10 else ''
    credits = tags[6] if len(tags)>6 else ''
    evidence = 'Source filename and embedded GD3 title/game; local package notes.'
    if 'All_New_World' in folder or folder == 'lemmings_3_music_mod_tsyu': game = 'lemmings3'
    elif 'Lemmings_3D' in folder: game = 'lemmings3d'
    elif 'Lemmings_2' in folder or 'Lemmings 2' in folder or folder == 'lemmings_2_music_mod_tsyu': game = 'lemmings2'
    elif folder == 'oh_no_more_lemmings_music_mod' or (tags and 'Oh No!' in tags[2]): game = 'ohno'
    elif folder == 'holiday_lemmings_music_mod' or (tags and ('Xmas' in tags[2] or 'Holiday' in tags[2])): game = 'holiday'
    elif folder == 'lemmings_demo_music_mod' or (tags and 'Demo' in tags[2]): game = 'demo'; role = 'demo'

    if folder in {'Archimedes', 'Lemmings (MP3)'}:
        metadata = json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format_tags','-of','json',str(path)]))['format'].get('tags',{})
        credits = metadata.get('artist','')
        source_notes = json.dumps(metadata,ensure_ascii=False,sort_keys=True)
        if folder == 'Archimedes':
            port = 'archimedes'
            title = re.sub(r'\s*\(Archimedes\)$', '', title, flags=re.I)
            key = next((v for k,v in COLLECTION_ALIASES.items() if normal(k)==normal(title)), None)
            evidence = 'Archimedes filenames and embedded A3010 recording claim. Filename corrections for Mariarti/Awesome take precedence over stale Unknown ID3 titles.'
        else:
            # Album, arranger, dumper, titles and durations match the published set.
            if metadata.get('artist') != 'Tomomi Hatakeyama' or metadata.get('dumper') not in {'Dragon Fogel','YK'}:
                raise ValueError(f'Unrecognised SNES collection metadata: {path}')
            port = 'snes'
            key = next((v for k,v in SNES_LEVELS.items() if normal(k)==normal(title)), None)
            evidence = 'https://www.zophar.net/music/nintendo-snes-spc/lemmings — matching titles, durations, arranger and dumpers. Level-labelled stage themes mapped through the documented Amiga/SNES score order, not generic title aliases. Region unverified.'
    elif folder == 'Lemmings-SMS':
        if len(tags)<5 or tags[4] != 'Sega Master System': raise ValueError(f'Missing SMS GD3 evidence: {path}')
        port = 'master-system'
        key = next((v for k,v in COLLECTION_ALIASES.items() if normal(k)==normal(title)), None)
        evidence = 'Embedded GD3 titles, composer credits and level associations; https://www.smspower.org/Music/Lemmings-SMS . Readme header v1.03 conflicts with history v2.00; preserve source evidence.'
    elif folder.startswith('CoLD SToRAGE'):

        quality = 'composer-recording'
        title = re.sub(r'^.* - \d+ Lemmings - ', '', path.stem)
        key = classic_key(title)
        evidence = 'Composer album titles; existing named-module mapping.'
    elif folder == 'Remixes':
        quality = 'lossy-source'; remix = 'mandelsoft'; port = 'dos-opl2'
        evidence = 'https://www.lemmingsforums.net/index.php?topic=3921.0 (author numbering and DOS order).'
        if path.parent.name == 'orig_special_music_mandelsoft':
            if path.stem.lower() not in {'beasti', 'beastii', 'menace', 'awesome'}:
                raise ValueError(f'Unknown special remix: {path}')
            key = path.stem.lower()
            evidence = 'Named special-level OGG in orig_special_music_mandelsoft; preserve special composition identity.'
        elif path.parent.name == 'paintball_music_mandelsoft':
            game = 'paintball'; port = 'windows'; key = 'mandelsoft-'+path.stem
            role = 'bonus'
            title = 'Paintball '+path.stem.removeprefix('lpb_')+' (MandelSoft)'
            evidence = 'Numbered OGG in paintball_music_mandelsoft. Original cue title and role unverified; separate bonus material.'
        elif path.stem.startswith('orig_'):
            # The author explicitly identifies 12 as Doggie (unlike the VGM package order).
            keys = ['lemming1','lemming2','lemming3','mountain','tenlemmings','cancan','tim1','tim2','tim3','tim4','tim5','doggie','tim6','tim7','tim8','tim9','tim10']
            key = keys[int(path.stem[-2:])-1]
        elif path.stem.startswith('ohno_'):
            game = 'ohno'; key = 'mandelsoft-'+path.stem
            confidence = 'unverified'; role = 'unverified'
            evidence = 'Numbered remix. Cross-port Oh No numbering differs; exact composition needs listening verification.'
        elif 'medieval' in path.name.lower():
            game = 'lemmings2'; port = 'amiga'; key = 'medieval'; remix = 'amigamer'
            evidence = 'Embedded ID3 title and artist identify Medieval Lemmings Remix by AmiGamer.'
        else:
            key = 'march-of-the-greentops'; remix = 'cold-storage'; port = 'amiga'; role = 'bonus'
            evidence = 'Embedded album tags. Preserve as a standalone composer remix until its constituent themes are verified.'
    if key is None:
        if game == 'classic':
            key = classic_key(title)
            if normal(title) == 'intro': key = 'intro'
        elif game == 'ohno':
            key = next(('tune'+str(i+1) for i,n in enumerate(OHNO) if normal(title)==normal(n)), None)
            if re.fullmatch('tune[1-6]', title.lower()): key = title.lower()
            evidence += ' Amiga tune4/5/6 correspond to DOS Much Joviality/Not At All Serious/The Smiling Blues; https://www.lemmingsforums.net/index.php?topic=4534.0'
        elif game == 'holiday':
            role = 'seasonal'
            key = next((k for n,k in [('jinglebells','jb'),('goodkingwenceslas','kw'),('rudi','rudi'),('jb','jb'),('kw','kw')] if normal(title).startswith(n)), None)
        elif game == 'lemmings2':
            n = normal(title)
            key = next((t for t in TRIBES if n.startswith(t)), None)
            if key is None: key = {'maintune':'maintune','maintheme':'maintune','endtune':'endtune','ending':'endtune'}.get(n)
            # These ports use different composers. A shared tribe slot is not proof of shared music.
            if port in {'game-boy','mega-drive'} and key:
                key = port+'-'+key
                evidence += ' Port-specific tribe composition; not substituted for the Amiga tune.'
        elif game == 'lemmings3':
            key = normal(title).replace('egyptian','egypt')
        elif game in {'demo','lemmings3d'}: key = slug(title)

    if key is None: key = port+'-'+slug(title)
    if game=='classic' and key in {'beasti','beastii','menace','awesome','mariarti'}: role='special'
    elif key in {'intro','maintune','frontend'} or any(n in title.lower() for n in ['opening','title theme','title screen','menu','frontend']): role='menu'
    elif key=='endtune' or 'ending' in title.lower(): role='ending'
    elif any(n in title.lower() for n in ['unknown']): role='unverified'; confidence='unverified'
    elif 'medal' in title.lower(): role='medal'
    elif 'tribe complete' in title.lower(): role='milestone'
    elif 'stage clear' in title.lower() or title.lower().startswith('clear ') or title.lower()=='success': role='victory'
    elif title.lower() in {'failed','failure','game over'}: role='failure'
    elif "let's go" in title.lower() or any(n in title.lower() for n in ['rating jingle','level pane']): role='cue'
    elif title.lower() in {'stage intro','trapdoor','oh no!'}: role='cue'
    elif title.lower()=='intermission': role='intermission'
    elif title.lower()=='staff roll': role='credits'
    elif 'sunsoft special' in title.lower(): role='special'
    # These were released as prototype/demo material, even where melodies recur.
    if game=='demo': role='demo'
    if game=='classic' and key=='mariarti': canonical_title='Professor Mariarti'
    elif game=='classic' and key in CLASSIC_TITLES: canonical_title=CLASSIC_TITLES[key]
    elif game=='ohno' and re.fullmatch('tune[1-6]',key): canonical_title=OHNO[int(key[-1])-1]
    elif game=='holiday': canonical_title={'jb':'Jingle Bells','kw':'Good King Wenceslas','rudi':'Rudolph the Red-Nosed Reindeer'}.get(key,title)
    else: canonical_title=key.replace('-',' ').title() if path.suffix=='.mod' else title
    if game=='lemmings2' and key in TRIBES: canonical_title=key.title()+' Tribe'
    if game=='lemmings2' and key in {'maintune','endtune'}: canonical_title={'maintune':'Main Theme','endtune':'Ending'}[key]
    if game=='lemmings3': canonical_title={'classic1':'Classic 1','classic2':'Classic 2','classic3':'Classic 3','egypt1':'Egyptian 1','egypt2':'Egyptian 2','shadow1':'Shadow 1','shadow2':'Shadow 2','frontend':'Frontend','intro':'Intro'}.get(key,title)
    if port == 'unknown':
        confidence = 'unverified'
        evidence += ' Platform is unverified; excluded from automatic selection.'
    archive = source if source.exists() else path.with_suffix('.ogg')
    variant = dict(id=slug(relative), path=relative, port=port, quality=quality, remix=remix,
        confidence=confidence, evidence=evidence, sourceNotes=source_notes, credits=credits or {'mandelsoft':'MandelSoft','cold-storage':'CoLD SToRAGE','amigamer':'AmiGamer'}.get(remix, 'CoLD SToRAGE' if folder.startswith('CoLD') else ''), sourcePath=archive.relative_to(music).as_posix() if archive.exists() else relative)
    return dict(id=game+'.'+key, game=game, title=canonical_title, role=role), variant


def build(music, destination, links):
    tracks={}
    files=sorted(p for p in music.rglob('*') if p.is_file() and not p.is_symlink() and 'By Track' not in p.parts and p.suffix.lower() in PLAYABLE)
    for path in files:
        track, variant=classify(path,music)
        entry=tracks.setdefault(track['id'],dict(**track,variants=[]))
        if entry['role']!=track['role']: raise ValueError(f'Conflicting roles: {track}')
        entry['variants'].append(variant)
    payload=dict(schemaVersion=1,tracks=sorted(tracks.values(),key=lambda t:t['id']))
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(payload,indent=2,ensure_ascii=False)+'\n')
    (music/'catalogue.json').write_text(destination.read_text())
    if links:
        view=music/'By Track'
        # Rebuild only generated links to known music assets. Never delete audio.
        known = {str(p.resolve()) for p in files}
        known.update(str(p.with_suffix(ext).resolve()) for p in files for ext in ['.vgz','.vgm','.ogg'])
        if view.exists():
            for link in view.rglob('*'):
                if link.is_symlink() and str(link.resolve()) in known: link.unlink()
            for directory in sorted(view.rglob('*'),key=lambda p:len(p.parts),reverse=True):
                if directory.is_dir() and not any(directory.iterdir()): directory.rmdir()
        for track in payload['tracks']:
            for variant in track['variants']:
                leaf=view/track['game']/track['role']/(track['id'].split('.',1)[1]+' - '+track['title'].replace('/','-'))/variant['port']/variant['quality']/variant['remix']
                leaf.mkdir(parents=True,exist_ok=True)
                for field in ['path','sourcePath']:
                    source=music/variant[field]
                    target=leaf/source.name
                    relative=os.path.relpath(source,leaf)
                    if target.is_symlink():
                        if os.readlink(target)==relative: continue
                        raise ValueError(f'Existing link differs: {target}')
                    if target.exists(): raise ValueError(f'Existing file: {target}')
                    target.symlink_to(relative)
    report=['# Track catalogue','',f'{len(files)} playable versions across {len(tracks)} track identities.','',
        'Browse `Sources/Music/By Track`: game → role → track → port → source quality → original/remix.', '',
        'The linked view preserves the source layout and conversion hashes. Unverified items remain separate from automatic journeys.', '']
    for track in payload['tracks']:
        report += [f'## {track["id"]} — {track["title"]}', '', f'Role: {track["role"]}', '', '| Port | Source quality | Remix | File |', '| --- | --- | --- | --- |']
        for v in track['variants']: report += [f'| {v["port"]} | {v["quality"]} | {v["remix"]} | {v["path"]} |']
        report += ['']
    (ROOT/'Documentation/MusicTrackCatalogue.md').write_text('\n'.join(report))
    print(f'{len(files)} variants, {len(tracks)} track identities; {sum(t["role"]=="unverified" for t in tracks.values())} unverified identities')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--music',type=Path,default=ROOT/'Sources/Music')
    parser.add_argument('--output',type=Path,default=ROOT/'Resources/Music/catalogue.json')
    parser.add_argument('--links',action='store_true')
    args=parser.parse_args()
    build(args.music.resolve(),args.output.resolve(),args.links)
