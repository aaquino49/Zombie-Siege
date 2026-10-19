"""T-054: replace only four sprites using transformed CC0 Kenney fragments.
Run: python project/tools/compose_footprint_buildings.py
Preserve 8x originals, alpha-trim, then Lanczos-downscale. No painted art.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
TILES = ROOT / 'asset_library/kenney/kenney_top-down-shooter/PNG/Tiles'
OUT = ROOT / 'game/assets/buildings'
ORIGINALS = ROOT / 'asset_library/generated/originals'
RUN = ROOT / 'project/runs/T-054/a1'
SCALE = 8
LANCZOS = Image.Resampling.LANCZOS
SOURCES = {}
CURRENT = ''
WOOD = (184, 130, 72)


def piece(number, width, height, color=None, rotation=0, core=False):
    source = f'tile_{number:02}.png'
    SOURCES.setdefault(CURRENT, set()).add(source)
    im = Image.open(TILES / source).convert('RGBA')
    # The opaque wood core supplies identical edges on all four wall sides.
    im = im.crop((12, 12, 52, 52)) if core else im.crop(im.getchannel('A').getbbox())
    if color:
        pixels = list(im.getdata())
        reference = max(sum(p[:3]) / 3 for p in pixels if p[3] == 255)
        im.putdata([tuple(round(min(255, c * sum(p[:3]) / (3 * reference)))
                          for c in color) + (p[3],) for p in pixels])
    if rotation:
        im = im.rotate(rotation, expand=True)
    return im.resize((width * SCALE, height * SCALE), LANCZOS)


def put(im, number, x, y, w, h, color=None, rotation=0, core=False):
    im.alpha_composite(piece(number, w, h, color, rotation, core), (x * SCALE, y * SCALE))


def beam(im, x, y, w, h, color=WOOD, metal=False):
    put(im, 520 if metal else 472, x, y, w, h, color, 90 if h > w else 0)


def wall(im):
    put(im, 349, 0, 0, 64, 64, WOOD, core=True)
    for x in (4, 18, 32, 46):
        beam(im, x, 4, 14, 56)
    for y in (12, 46):
        beam(im, 4, y, 56, 6, (149, 101, 56))
    for x in (8, 52):
        for y in (13, 47):
            put(im, 479, x, y, 4, 4, (118, 82, 47))


def gate(im):
    wall(im)
    # Closed double doors: light panels, a frame, cross-braces, and latch.
    put(im, 456, 8, 8, 48, 48, (140, 95, 52))
    for x in (12, 33):
        put(im, 456, x, 12, 19, 40, (219, 170, 108))
        diagonal = piece(472, 37, 4, (161, 110, 62)).rotate(
            65 if x == 12 else -65, Image.Resampling.BICUBIC, expand=True)
        im.alpha_composite(diagonal, ((x + 3) * SCALE, 15 * SCALE))
    beam(im, 24, 28, 16, 8, (161, 174, 171), metal=True)
    for x in (10, 50):
        for y in (16, 44):
            beam(im, x, y, 4, 6, (130, 145, 146), metal=True)


def reinforced(im):
    wall(im)
    # Same wood silhouette; broad grey plates and eight readable rivets.
    for y in (7, 33):
        put(im, 456, 7, y, 50, 24, (152, 167, 169))
        beam(im, 10, y + 3, 44, 3, (189, 199, 195), metal=True)
        for x in (11, 49):
            for ry in (y + 5, y + 16):
                put(im, 360, x, ry, 5, 5, (92, 111, 115))


def shelter(im):
    # One green roof across the 2x2 footprint, connected to its entrance.
    put(im, 456, 4, 6, 120, 114, (85, 121, 88))
    put(im, 349, 9, 11, 55, 104, (91, 133, 95), core=True)
    put(im, 349, 64, 11, 55, 104, (103, 145, 105), core=True)
    beam(im, 61, 9, 6, 108, (132, 161, 114))
    for y in (28, 88):
        beam(im, 8, y, 112, 4, (152, 172, 125))
    put(im, 504, 48, 105, 32, 19, (111, 125, 111), rotation=90)
    beam(im, 44, 121, 40, 4, (184, 160, 112))
    for x in (2, 120):
        for y in (5, 116):
            put(im, 479, x, y, 6, 6, (167, 139, 90))


def save(name, size, build):
    global CURRENT
    CURRENT = name
    im = Image.new('RGBA', (size * SCALE, size * SCALE))
    build(im)
    im.save(ORIGINALS / f't054_{name}_8x.png')
    trimmed = im.crop(im.getchannel('A').getbbox())
    extent = size if size == 64 else size - 4
    final = trimmed.resize((extent, extent), LANCZOS)
    canvas = Image.new('RGBA', (size, size))
    canvas.alpha_composite(final, ((size - extent) // 2, (size - extent) // 2))
    canvas.save(OUT / f'{name}.png')


def contact_sheet():
    sheet = Image.new('RGB', (1000, 580), (34, 43, 38))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)
    draw.text((20, 14), 'T-054 | Kenney compositions | native 1x and half zoom', font=font, fill='white')
    names = ['wall_wood', 'gate', 'wall_reinforced', 'shelter', 'command_center', 'storage']
    for i, name in enumerate(names):
        x, y = 20 + (i % 3) * 326, 58 + (i // 3) * 220
        grass = Image.open(ROOT / 'game/assets/tiles/grass_1.png').convert('RGB')
        for tx in range(4):
            for ty in range(2):
                sheet.paste(grass, (x + tx * 64, y + ty * 64))
        sprite = Image.open(OUT / f'{name}.png').convert('RGBA')
        sheet.paste(sprite, (x, y), sprite)
        half = sprite.resize((sprite.width // 2, sprite.height // 2), LANCZOS)
        sheet.paste(half, (x + 160, y + 32), half)
        draw.text((x, y + 140), name, font=font, fill='white')
    draw.text((20, 520), 'Unchanged CC / storage references; all pieces: Kenney Top-Down Shooter (CC0).', font=font, fill='white')
    sheet.save(RUN / 'contact_sheet.png')


def main():
    ORIGINALS.mkdir(parents=True, exist_ok=True)
    RUN.mkdir(parents=True, exist_ok=True)
    for name, size, build in [('wall_wood', 64, wall), ('gate', 64, gate),
                              ('wall_reinforced', 64, reinforced), ('shelter', 128, shelter)]:
        save(name, size, build)
    sources = {k: sorted(v) for k, v in SOURCES.items()}
    (ORIGINALS / 't054_sources.json').write_text(json.dumps(sources, indent=2) + '\n', encoding='utf-8')
    contact_sheet()
    print('Replaced four sprites; preserved 8x Kenney-derived originals and contact sheet.')


if __name__ == '__main__':
    main()
