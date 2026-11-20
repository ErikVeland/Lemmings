#!/usr/bin/env python3
"""Project game renderings onto the two glass panels of an illustrated Duo."""
from argparse import ArgumentParser
from pathlib import Path
import subprocess
import tempfile

ASSETS = Path(__file__).resolve().parent / 'assets'
# Corners in the 1536 × 1024 illustrations, ordered TL, TR, BL, BR.
TENT = [(376, 170), (1170, 167), (311, 729), (1106, 749)]
BOOK = [[(306, 148), (765, 187), (306, 779), (765, 741)],
        [(767, 187), (1219, 148), (767, 741), (1219, 779)]]
TABLETOP = [[(241, 108), (1290, 108), (241, 518), (1290, 518)],
            [(241, 529), (1290, 529), (130, 813), (1400, 813)]]

def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)

def project(source, crop, corners, output):
    x, y, width, height = crop
    source_corners = [(0, 0), (width-1, 0), (0, height-1), (width-1, height-1)]
    controls = ' '.join(f'{sx},{sy} {dx},{dy}' for (sx, sy), (dx, dy) in zip(source_corners, corners))
    radius = round(min(width, height) * .04)
    run('magick', source, '-crop', f'{width}x{height}+{x}+{y}', '+repage',
        '(', '+clone', '-alpha', 'off', '-fill', 'black', '-colorize', '100', '-fill', 'white',
        '-draw', f'roundrectangle 0,0 {width-1},{height-1} {radius},{radius}', ')',
        '-compose', 'CopyOpacity', '-composite', '-virtual-pixel', 'transparent',
        '-define', 'distort:viewport=1536x1024+0+0', '-distort', 'Perspective', controls, output)

def dimensions(source):
    result = subprocess.check_output(['magick', 'identify', '-format', '%w %h', source], text=True)
    return tuple(map(int, result.split()))

def photo(artwork, screen, pose, corners, directory):
    width, height = dimensions(screen)
    if pose == 'tent':
        crops = [(0, 0, width, height)]
    elif pose == 'book':
        # The native 3× display reserves 40 points at the hinge.
        panel = (width - 120) // 2
        crops = [(0, 0, panel, height), (width-panel, 0, panel, height)]
    else:
        panel = (height - 120) // 2
        crops = [(0, 0, width, panel), (0, height-panel, width, panel)]
    layers = []
    for i, (crop, quad) in enumerate(zip(crops, corners)):
        layer = directory / f'{pose}-{i}.png'
        project(screen, crop, quad, layer)
        layers += [layer, '-compose', 'over', '-composite']
    run('magick', artwork / f'{pose}.png', *layers, '-resize', '1200x800',
        '-quality', '88', ASSETS / f'duo-{pose}-scene.webp')

def film(artwork, directory):
    # Only the glass changes between frames. Render the frame and its mask once.
    mask = directory/'glass.png'
    white = directory/'white.png'
    width, height = dimensions(ASSETS/'duo-desk-clock.webp')
    run('magick', '-size', f'{width}x{height}', 'xc:white', white)
    project(white, (0, 0, width, height), TENT, mask)
    run('magick', mask, '-alpha', 'extract', '-resize', '1152x768!', directory/'alpha.png')
    xy = ':'.join(f'x{i}={x*.75}:y{i}={y*.75}' for i,(x,y) in enumerate(TENT))
    filters = ('[0:v]scale=1152:768,setsar=1,format=gbrp[wood];'
               '[1:v]scale=1152:768,setsar=1,format=gbrp,perspective=' + xy + ':sense=destination[display];'
               '[2:v]format=gbrp[mask];[wood][display][mask]maskedmerge,format=yuv420p[out]')
    run('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-filter_complex_threads', '1',
        '-loop', '1', '-framerate', '15', '-i', artwork/'tent.png',
        '-i', ASSETS/'duo-desk-clock.mp4', '-loop', '1', '-framerate', '15', '-i', directory/'alpha.png',
        '-filter_complex', filters, '-map', '[out]', '-an', '-t', '27', '-c:v', 'libx264',
        '-threads', '2', '-preset', 'fast', '-crf', '17', '-movflags', '+faststart', ASSETS/'duo-tent-scene.mp4')

if __name__ == '__main__':
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('artwork', type=Path, help='Folder containing book.png, tabletop.png and tent.png')
    parser.add_argument('--tent', type=Path, default=ASSETS/'duo-cover-full.webp')
    parser.add_argument('--book', type=Path, default=ASSETS/'book-full.webp')
    parser.add_argument('--tabletop', type=Path, default=ASSETS/'tabletop-full.webp')
    parser.add_argument('--film', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as scratch:
        directory = Path(scratch)
        photo(args.artwork, args.book, 'book', BOOK, directory)
        photo(args.artwork, args.tabletop, 'tabletop', TABLETOP, directory)
        photo(args.artwork, args.tent, 'tent', [TENT], directory)
        if args.film:
            film(args.artwork, directory)
