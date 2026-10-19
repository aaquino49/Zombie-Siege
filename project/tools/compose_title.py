"""Rebuild T-031 release art from curated CC0 Kenney sprites (Pillow).

Run from any directory: python project/tools/compose_title.py
Only writes release assets, retained composition masters and review contact sheets.
No image-generation service is used. Source provenance follows ASSET_INDEX.md.
"""
from pathlib import Path
import hashlib
import json
import random

from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "game/assets"
ORIGINALS = ROOT / "asset_library/generated/originals"
RUN = ROOT / "project/runs/T-031"
SCALE = 2
LANCZOS = Image.Resampling.LANCZOS
QUIET = (320, 195, 960, 525)
SOURCES = {}


def source(relative):
    path = ASSETS / relative
    SOURCES[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    return Image.open(path).convert("RGBA")


def stamp(canvas, relative, x, y, size=None, angle=0, tint=None):
    sprite = source(relative)
    if size is None:
        size = sprite.size
    sprite = sprite.resize(tuple(round(v * SCALE) for v in size), LANCZOS)
    if tint:
        sprite = tint_image(sprite, tint)
    if angle:
        sprite = sprite.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    canvas.alpha_composite(sprite, (round(x * SCALE), round(y * SCALE)))


def tint_image(image, factors):
    channels = list(image.split())
    for i, factor in enumerate(factors):
        channels[i] = channels[i].point(lambda value: round(value * factor))
    return Image.merge("RGBA", channels)


def title():
    rng = random.Random(31)
    canvas = Image.new("RGBA", (1280 * SCALE, 720 * SCALE))
    # Lower texture contrast everywhere, retaining the source tile geometry.
    for y in range(0, 720, 64):
        for x in range(0, 1280, 64):
            tile = source(f"tiles/grass_{rng.randint(1, 3)}.png")
            flat = Image.new("RGBA", tile.size, (41, 174, 103, 255))
            tile = Image.blend(flat, tile, .22)
            canvas.alpha_composite(tile.resize((128, 128), LANCZOS), (x * SCALE, y * SCALE))

    # The camp path runs around the panel space, never through it.
    path = [(x, y) for y in (128, 576) for x in range(256, 1024, 64)]
    path += [(x, y) for x in (256, 960) for y in range(192, 576, 64)]
    for x, y in path:
        # Native grass/dirt edges soften the rim without inventing a texture.
        stamp(canvas, "tiles/path/path_center.png", x, y)
    for x in range(256, 1024, 64):
        stamp(canvas, "tiles/path/path_edge_s.png", x, 128)
        stamp(canvas, "tiles/path/path_edge_n.png", x, 576)
    for y in range(192, 576, 64):
        stamp(canvas, "tiles/path/path_edge_e.png", 256, y)
        stamp(canvas, "tiles/path/path_edge_w.png", 960, y)

    # Forest silhouettes and invading walkers stay outside the camp.
    for y in range(-16, 752, 53):
        for x in list(range(-24, 184, 53)) + list(range(1120, 1310, 53)):
            stamp(canvas, f"props/tree_{rng.randint(1, 2)}.png",
                  x + rng.randint(-12, 12), y + rng.randint(-13, 13),
                  (rng.randint(55, 78),) * 2, tint=(.70, .79, .72))
    for x in range(172, 1120, 57):
        for y in (-32, 698):
            stamp(canvas, "props/tree_1.png", x + rng.randint(-10, 10), y,
                  (70, 70), tint=(.70, .79, .72))

    # Thin wall strips are cropped from the actual four-sided wooden barrier.
    wood = source("buildings/wall_wood.png").crop((0, 0, 64, 23))
    horizontal = wood.resize((64 * SCALE, 23 * SCALE), LANCZOS)
    vertical = horizontal.transpose(Image.Transpose.ROTATE_90)
    for x in range(224, 1056, 64):
        canvas.alpha_composite(horizontal, (x * SCALE, 40 * SCALE))
        if x != 608:
            canvas.alpha_composite(horizontal, (x * SCALE, 660 * SCALE))
    for y in range(63, 639, 64):
        canvas.alpha_composite(vertical, (224 * SCALE, y * SCALE))
        canvas.alpha_composite(vertical, (1033 * SCALE, y * SCALE))
    stamp(canvas, "buildings/gate.png", 608, 636)
    # Warm warning lamps accent the wall where walkers are approaching.
    for x, y in [(222, 219), (222, 459), (1031, 219), (1031, 459)]:
        stamp(canvas, "props/scrap_2.png", x, y, (26, 26), tint=(1.0, .68, .55))

    # Buildings frame the empty courtyard: all detail is outside QUIET.
    for name, x, y in [("command_center", 416, 63), ("shelter", 568, 63),
                       ("farm", 368, 532), ("workshop", 704, 532)]:
        stamp(canvas, f"buildings/{name}.png", x, y)
    stamp(canvas, "buildings/watchtower.png", 952, 532)
    stamp(canvas, "buildings/watchtower.png", 256, 76)
    stamp(canvas, "buildings/storage.png", 252, 388, (64, 128))
    stamp(canvas, "buildings/lumber_yard.png", 961, 320, (64, 128))

    # A partly assembled radio with exposed scaffolding and staged hardware.
    stamp(canvas, "buildings/construction_2x2.png", 844, 64)
    radio = source("buildings/radio_tower.png")
    radio.putalpha(ImageEnhance.Brightness(radio.getchannel("A")).enhance(.80))
    radio = radio.crop((0, 0, 64, 128)).resize((128, 256), LANCZOS)
    canvas.alpha_composite(radio, (844 * SCALE, 64 * SCALE))
    stamp(canvas, "props/scrap_3.png", 973, 114, (36, 36))
    stamp(canvas, "characters/survivor_brown_stand.png", 980, 158, angle=90)

    for x, y, angle in [(337, 96, 30), (548, 140, 180), (861, 551, 0),
                         (971, 544, 180), (264, 285, -90), (1021, 250, 90)]:
        stamp(canvas, "characters/survivor_blue_gun.png", x, y, angle=angle)
    for x, y, angle in [(175, 214, 0), (173, 287, -20), (140, 361, 15),
                         (173, 480, 25), (113, 548, -10), (1088, 196, 180),
                         (1110, 266, 165), (1080, 384, 190), (1133, 459, 150),
                         (1086, 551, 195), (119, 178, -15), (1158, 592, 160)]:
        stamp(canvas, "characters/zombie_stand.png", x, y, angle=angle,
              tint=(.85, 1.0, .84))
    for x, y in [(201, 586), (1092, 89), (82, 316), (1179, 414)]:
        stamp(canvas, "props/rock_1.png", x, y)

    # Uniform dusk color grade. Edge darkening uses flat bands, not gradients.
    canvas = tint_image(canvas, (.69, .72, .81))
    shade = Image.new("RGBA", canvas.size)
    draw = ImageDraw.Draw(shade)
    for inset, opacity in [(0, 19), (24, 12), (56, 8)]:
        draw.rectangle((inset * SCALE, inset * SCALE,
                        (1280 - inset) * SCALE - 1, (720 - inset) * SCALE - 1),
                       outline=(15, 23, 29, opacity), width=24 * SCALE)
    canvas.alpha_composite(shade)
    master = canvas.convert("RGB")
    master.save(ORIGINALS / "t031_title_art_2x.png")
    final = master.resize((1280, 720), LANCZOS)
    final.save(ASSETS / "ui/title_art.png")
    return final


def icon():
    # Strong roof silhouette plus a bold overhead radio mast; few small details.
    canvas = Image.new("RGBA", (1024, 1024))
    building = source("buildings/command_center.png")
    building = building.crop(building.getchannel("A").getbbox())
    building = building.resize((864, 808), LANCZOS)
    canvas.alpha_composite(building, (80, 184))
    radio = source("buildings/radio_tower.png")
    # Retain original metal shading, scale the simple main aerial separately.
    pole = radio.crop((61, 6, 67, 60)).resize((52, 364), LANCZOS)
    crossbar = radio.crop((6, 61, 122, 67)).resize((416, 40), LANCZOS)
    canvas.alpha_composite(pole, (486, 28))
    canvas.alpha_composite(crossbar, (304, 112))
    fixture = radio.crop((41, 41, 87, 87)).resize((172, 172), LANCZOS)
    canvas.alpha_composite(fixture, (426, 292))
    canvas.save(ORIGINALS / "t031_icon_4x.png")
    final = canvas.resize((256, 256), LANCZOS)
    final.save(ASSETS / "icon/icon.png")
    final.save(ASSETS / "icon/icon.ico", sizes=[(n, n) for n in (16, 32, 48, 64, 128, 256)])
    return final


def contact_sheet(background, app_icon):
    sheet = Image.new("RGB", (1200, 740), (32, 41, 38))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
    except OSError:
        font = ImageFont.load_default(size=18)
    draw.text((24, 14), "T-031 | Kenney sprite compositions | no generated-image service", font=font, fill="white")
    sheet.paste(background.resize((640, 360), LANCZOS), (24, 58))
    draw.text((24, 426), "Title: 1280x720 -> 640x360; central panel space reserved", font=font, fill="white")
    draw.text((716, 30), "App icon: actual 256 / 64 / 32 / 16 px", font=font, fill="white")
    for n, x, y in [(256, 720, 62), (64, 1000, 62), (32, 1080, 62), (16, 1140, 62)]:
        for yy in range(y, y + n, 8):
            for xx in range(x, x + n, 8):
                draw.rectangle((xx, yy, min(xx + 7, x + n - 1), min(yy + 7, y + n - 1)),
                               fill=(79, 89, 85) if ((xx-x)//8+(yy-y)//8)%2 else (59, 68, 65))
        im = app_icon.resize((n, n), LANCZOS)
        sheet.paste(im, (x, y), im)
        draw.text((x, y + n + 8), str(n), font=font, fill="white")
    draw.text((24, 478), "Unchanged in-game sprites below, at native size (same source artwork)", font=font, fill="white")
    comparisons = ["buildings/command_center.png", "buildings/radio_tower.png",
                   "buildings/construction_2x2.png", "buildings/watchtower.png",
                   "props/tree_1.png", "characters/zombie_stand.png",
                   "characters/survivor_blue_gun.png", "tiles/grass_1.png"]
    for i, relative in enumerate(comparisons):
        x, y = 24 + i * 145, 520
        sprite = source(relative)
        sheet.paste(sprite, (x + (128 - sprite.width)//2, y), sprite)
        draw.text((x, y + 137), Path(relative).stem.replace("_", " "),
                  font=ImageFont.load_default(size=12), fill="white")
    sheet.save(RUN / "contact_sheet.png")
    sheet.save(RUN / "a1/contact_sheet.png")
    # A review-only overlay proves the calm area; never shipped in title art.
    overlay = background.copy()
    ImageDraw.Draw(overlay).rectangle(QUIET, outline=(226, 174, 99), width=2)
    overlay.save(RUN / "a1/title_panel_region.png")


def main():
    for folder in [ORIGINALS, ASSETS / "ui", ASSETS / "icon", RUN / "a1"]:
        folder.mkdir(parents=True, exist_ok=True)
    background, app_icon = title(), icon()
    contact_sheet(background, app_icon)
    manifest = {
        "task": "T-031", "method": "Deterministic Pillow composition of curated Kenney CC0 sprites; no AI generation",
        "rebuild": "python project/tools/compose_title.py", "seed": 31,
        "title": {"master": "t031_title_art_2x.png", "size": [1280, 720], "mode": "RGB",
                  "quiet_region": list(QUIET), "processing": "2x composition, uniform dusk tint, flat edge shade bands, Lanczos downscale"},
        "icon": {"master": "t031_icon_4x.png", "size": [256, 256], "mode": "RGBA",
                 "ico_sizes": [16, 32, 48, 64, 128, 256],
                 "processing": "Alpha-trimmed Command Center plus metal radio fragments on transparent 4x canvas; Lanczos downscale"},
        "sources_sha256_relative_to_game_assets": dict(sorted(SOURCES.items())),
        "provenance": "See game/assets/ASSET_INDEX.md and CREDITS.md: Kenney Top-Down Shooter and Tower Defense (Top-Down), CC0",
    }
    (ORIGINALS / "t031_sources.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("Rebuilt title art, transparent PNG/ICO, retained masters, manifest and both contact sheets.")


if __name__ == "__main__":
    main()
