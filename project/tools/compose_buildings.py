"""Rebuild T-007 sprites from local CC0 Kenney pieces (Pillow required).

No painted stand-ins: every visible pixel is a transformed pack fragment.
Run from the repository root: python project/tools/compose_buildings.py
"""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
TILES = ROOT / 'asset_library/kenney/kenney_top-down-shooter/PNG/Tiles'
OUT = ROOT / 'game/assets/buildings'
RUN = ROOT / 'project/runs/T-007/a1'
LANCZOS = Image.Resampling.LANCZOS
SOURCES = {}
CURRENT = ''


def piece(number, size=None, color=None, angle=0):
    source = f'tile_{number:02}.png'
    SOURCES.setdefault(CURRENT, set()).add(source)
    im = Image.open(TILES / source).convert('RGBA')
    im = im.crop(im.getchannel('A').getbbox())
    if color:
        # Preserve the original shading and antialiased alpha when recoloring.
        opaque = [p for p in im.getdata() if p[3] == 255]
        reference = max(sum(p[:3]) / 3 for p in opaque)
        im.putdata([tuple(round(min(255, c * ((sum(p[:3]) / 3) / reference)))
                          for c in color) + (p[3],) for p in im.getdata()])
    if size:
        im = im.resize(size, LANCZOS)
    if angle:
        im = im.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    return im


def paste(canvas, im, x, y):
    canvas.alpha_composite(im, (round(x), round(y)))


def bar(canvas, x, y, width, height, metal=False, color=None, angle=0):
    im = piece(520 if metal else 472, (width, height), color, angle)
    paste(canvas, im, x, y)


def roof(canvas, x, y, width, height, color):
    base = piece(456, (width, height), color)
    # Two flat planes and a narrow ridge read as an overhead pitched roof.
    left = piece(456, (width, height), tuple(round(c * .89) for c in color))
    base.alpha_composite(left.crop((0, 0, width // 2, height)), (0, 0))
    paste(canvas, base, x, y)
    bar(canvas, x + width // 2 - 2, y + 3, 4, height - 6,
        color=tuple(min(255, round(c * 1.08)) for c in color))


def frame(canvas, x, y, width, height, thickness=5, metal=False):
    bar(canvas, x, y, width, thickness, metal)
    bar(canvas, x, y + height - thickness, width, thickness, metal)
    bar(canvas, x, y, thickness, height, metal)
    bar(canvas, x + width - thickness, y, thickness, height, metal)


def save(name, size, build):
    global CURRENT
    CURRENT = name
    canvas = Image.new('RGBA', (size, size))
    build(canvas)
    canvas.save(OUT / f'{name}.png')


def command_center(im):
    roof(im, 10, 16, 108, 88, (199, 110, 53))
    paste(im, piece(457, (22, 28), (153, 184, 182)), 26, 43)
    paste(im, piece(457, (22, 28), (153, 184, 182)), 80, 43)
    paste(im, piece(538, (30, 17)), 49, 103)
    paste(im, piece(360, (16, 16), (187, 191, 183)), 84, 22)
    bar(im, 90, 24, 3, 12, True)


def shelter(im):
    for x in (14, 72):
        roof(im, x, 22, 42, 80, (89, 133, 96))
        paste(im, piece(504, (18, 15)), x + 12, 87)
        for yy in (17, 103):
            bar(im, x - 4, yy, 50, 3, color=(197, 183, 143))
            for xx in (x - 5, x + 44):
                paste(im, piece(479, (5, 5)), xx, yy - 1)


def farm(im):
    paste(im, piece(5, (110, 110)), 9, 9)
    frame(im, 8, 8, 112, 112, 4)
    for row in range(5):
        bar(im, 16, 17 + row * 20, 96, 12, color=(121, 82, 48))
        for col in range(4):
            paste(im, piece(134, (17, 16)), 20 + col * 23, 15 + row * 20)


def storage(im):
    paste(im, piece(96, (106, 96)), 11, 20)
    frame(im, 10, 18, 108, 100, 5)
    for x, y, sz in [(19, 62, 28), (51, 62, 28), (84, 62, 25),
                     (23, 94, 20), (48, 94, 20)]:
        paste(im, piece(129, (sz, sz)), x, y)
    paste(im, piece(316, (19, 19)), 87, 94)
    roof(im, 8, 12, 112, 43, (176, 139, 87))


def workshop(im):
    roof(im, 10, 20, 108, 82, (139, 147, 150))
    for x in (23, 37, 49, 77, 89, 103):
        bar(im, x, 25, 2, 72, True, (155, 164, 168))
    paste(im, piece(360, (21, 21), (191, 197, 190)), 84, 30)
    paste(im, piece(369, (9, 9), (92, 103, 106)), 90, 36)
    paste(im, piece(504, (33, 18)), 48, 101)
    paste(im, piece(316, (17, 17)), 14, 105)
    paste(im, piece(269, (18, 13)), 93, 106)


def lumber_yard(im):
    for x, y in [(12, 20), (12, 49), (12, 78)]:
        for j in range(3):
            bar(im, x, y + j * 7, 58, 7)
            paste(im, piece(479, (8, 8)), x + 52, y + j * 7)
        bar(im, x + 13, y, 4, 22, color=(118, 93, 67))
        bar(im, x + 38, y, 4, 22, color=(118, 93, 67))
    roof(im, 80, 16, 36, 55, (191, 151, 92))
    paste(im, piece(129, (25, 25)), 85, 79)
    paste(im, piece(266, (29, 25)), 78, 103)


def radio_tower(im):
    frame(im, 23, 23, 82, 82, 7, True)
    for angle in (45, -45):
        cross = piece(520, (105, 5), angle=angle)
        paste(im, cross, (128 - cross.width) // 2, (128 - cross.height) // 2)
    for x in (16, 93):
        for y in (16, 93):
            paste(im, piece(360, (19, 19), (145, 158, 158)), x, y)
    for x, y, w, h in [(61, 6, 6, 116), (6, 61, 116, 6)]:
        bar(im, x, y, w, h, True, (182, 190, 186))
    for x, y in [(10, 50), (10, 73), (105, 50), (105, 73)]:
        bar(im, x, y, 13, 4, True)
    paste(im, piece(360, (46, 46), (201, 207, 197)), 41, 41)
    paste(im, piece(369, (15, 15), (109, 126, 130)), 56, 56)
    paste(im, piece(316, (8, 8)), 60, 60)


def watchtower(im):
    paste(im, piece(96, (46, 46)), 9, 6)
    frame(im, 7, 4, 50, 50, 5)
    for x in (5, 50):
        for y in (2, 47):
            paste(im, piece(130, (9, 9)), x, y)
    for y in (53, 57, 61):
        bar(im, 26, y, 12, 3)


def gate(im):
    bar(im, 0, 24, 29, 16)
    bar(im, 35, 24, 29, 16)
    for x in (4, 52):
        bar(im, x, 17, 8, 30)
        paste(im, piece(360, (5, 5), (183, 185, 169)), x + 1, 30)
    bar(im, 27, 27, 10, 10, True, (164, 170, 165))


def reinforced_wall(im):
    paste(im, Image.open(OUT / 'wall_wood.png').convert('RGBA'), 0, 0)
    SOURCES[CURRENT] = {'tile_472.png'}
    for y in (24, 36):
        bar(im, 0, y, 64, 4, True, (144, 160, 161))
    for x in (7, 29, 51):
        bar(im, x, 21, 6, 22, True, (184, 193, 185))
        for y in (25, 35):
            paste(im, piece(360, (3, 3), (99, 117, 120)), x + 1, y)


def construction(im):
    n = im.width
    frame(im, 7, 7, n - 14, n - 14, 6)
    for angle in (45, -45):
        beam = piece(472, (round((n - 24) * math.sqrt(2)), 5), angle=angle)
        paste(im, beam, (n - beam.width) // 2, (n - beam.height) // 2)
    for x in (3, n - 13):
        for y in (3, n - 13):
            paste(im, piece(130, (10, 10)), x, y)
    paste(im, piece(266, (round(n * .27), round(n * .23))), n * .62, n * .62)


def contact_sheet():
    names = list(SOURCES) + ['turret_base', 'turret_barrel']
    cols, cw, ch = 5, 240, 228
    sheet = Image.new('RGB', (cols * cw, 84 + 3 * ch), (34, 43, 38))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 16)
    draw.text((20, 14), 'T-007 | Kenney building compositions | actual pixels, 1x zoom', font=font, fill='white')
    draw.text((20, 44), '64px grass tiles + unchanged T-001 survivors; labels are outside sprite assets.', font=font, fill=(185, 203, 181))
    for i, name in enumerate(names):
        x, y = (i % cols) * cw + 24, 84 + (i // cols) * ch
        for tx in range(3):
            for ty in range(3):
                tile = Image.open(ROOT / f'game/assets/tiles/grass_{1 + ((tx + ty) % 3)}.png')
                sheet.paste(tile, (x + tx * 64, y + ty * 64))
        sprite = Image.open(OUT / f'{name}.png').convert('RGBA')
        sheet.paste(sprite, (x + (128 - sprite.width) // 2, y + (128 - sprite.height) // 2), sprite)
        survivor = Image.open(ROOT / 'game/assets/characters/survivor_blue_stand.png').convert('RGBA')
        sheet.paste(survivor, (x + 138, y + 75), survivor)
        draw.text((x, y + 196), f'{name} ({sprite.width})', font=font, fill='white')
    sheet.save(RUN / 'contact_sheet.png')


def main():
    global CURRENT
    OUT.mkdir(parents=True, exist_ok=True)
    RUN.mkdir(parents=True, exist_ok=True)
    for name, build in [('command_center', command_center), ('shelter', shelter),
                        ('farm', farm), ('storage', storage), ('workshop', workshop),
                        ('lumber_yard', lumber_yard), ('radio_tower', radio_tower)]:
        save(name, 128, build)
    # Move the unchanged T-001 wall to its one canonical location.
    CURRENT = 'wall_wood'
    SOURCES[CURRENT] = {'tile_472.png'}
    original = ROOT / 'game/assets/props/wall_wood.png'
    Image.open(TILES / 'tile_472.png').save(OUT / 'wall_wood.png')
    if original.exists():
        original.unlink()
    companion = original.with_suffix('.png.import')
    if companion.exists():
        companion.unlink()
    for name, build in [('watchtower', watchtower), ('gate', gate), ('wall_reinforced', reinforced_wall)]:
        save(name, 64, build)
    save('construction_1x1', 64, construction)
    save('construction_2x2', 128, construction)
    contact_sheet()
    (RUN / 'composition_sources.json').write_text(json.dumps(
        {k: sorted(v) for k, v in SOURCES.items()}, indent=2) + '\n', encoding='utf-8')
    print(f'Created {len(SOURCES)} building sprites and true-size contact sheet.')


if __name__ == '__main__':
    main()
