"""T-108 native UI kit. Run from any cwd; requires Pillow and fontTools.

No resizing of shipping art. Pack masks/pixels are recombined; only missing
semantic glyphs are hand-placed. Every output is checked against palette.json.
"""
from pathlib import Path
import hashlib
import json

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[3]
PACK = ROOT / "asset_library/ittaimanero"
OUT = ROOT / "game/assets/pixel/ui"
RUN = ROOT / "project/runs/T-108/a1"
PALETTE = {tuple(bytes.fromhex(c[1:])) for c in json.loads((PACK / "palette.json").read_text())}
SOURCES = {int(p.stem.rsplit("-", 1)[1]): p for p in (PACK / "sprites").rglob("*Capa-*.png")}
ASSETS = {}
FONT = OUT / "font/pixelify_sans.ttf"


def color(value):
    rgb = tuple(bytes.fromhex(value.lstrip("#")))
    assert rgb in PALETTE
    return (*rgb, 255)


def blank(size):
    return Image.new("RGBA", size)


def pack_image(number):
    return Image.open(SOURCES[number]).convert("RGBA")


def slot(name):
    return Image.open(PACK / "sprites/Inventory interface" / (name + ".png")).convert("RGBA")


def validate(im):
    pixels = list(im.get_flattened_data())
    assert {p[:3] for p in pixels if p[3]} <= PALETTE
    assert {p[3] for p in pixels} <= {0, 255}


def save(name, im, source, purpose, margins=None, processing=""):
    validate(im)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / (name + ".png")
    im.save(path)
    ASSETS[name] = dict(file=path.relative_to(ROOT).as_posix(), size=list(im.size),
                        sources=source, purpose=purpose, margins=margins,
                        processing=processing, sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def framed(fill, rim, detail, inset=False, selected=False):
    """Keep EMPTY_SLOT alpha/chamfers, close its missing side border runs.

    The selected source supplies the highlight, not a newly drawn contour.
    A one-pixel eroded interior mask gives pressed/toggle their inset bevel.
    """
    base = slot("EMPTY_SLOT")
    alpha = base.getchannel("A")
    # MinFilter clamps at the canvas edge; explicitly pad with transparent pixels
    # so the long straight sides get the same rim as the chamfered corners.
    interior = ImageOps.expand(alpha, 1, fill=0).filter(ImageFilter.MinFilter(3)).crop((1, 1, 33, 23))
    out = blank(base.size)
    for y in range(base.height):
        for x in range(base.width):
            p = base.getpixel((x, y))
            if not p[3]:
                continue
            value = rim if not interior.getpixel((x, y)) else fill
            if p[:3] == (48, 43, 43):
                value = detail
            out.putpixel((x, y), color(value))
    if inset:
        inner2 = interior.filter(ImageFilter.MinFilter(3))
        for y in range(base.height):
            for x in range(base.width):
                if interior.getpixel((x, y)) and not inner2.getpixel((x, y)):
                    out.putpixel((x, y), color("#080707" if y < base.height // 2 else detail))
    if selected:
        highlight = slot("USING_SLOT")
        for y in range(base.height):
            for x in range(base.width):
                if highlight.getpixel((x, y)) == (255, 255, 255, 255):
                    out.putpixel((x, y), color(rim))
    return out


def slice_image(im, size, margins):
    """Nine-slice in native units: preserve corners, tile edge/centre pixels."""
    left, top, right, bottom = margins
    w, h = size
    assert w >= left + right and h >= top + bottom
    xs = [0, left, im.width - right, im.width]
    ys = [0, top, im.height - bottom, im.height]
    dx = [0, left, w - right, w]
    dy = [0, top, h - bottom, h]
    out = blank(size)
    for row in range(3):
        for col in range(3):
            tile = im.crop((xs[col], ys[row], xs[col + 1], ys[row + 1]))
            for y in range(dy[row], dy[row + 1], tile.height):
                for x in range(dx[col], dx[col + 1], tile.width):
                    part = tile.crop((0, 0, min(tile.width, dx[col + 1] - x),
                                      min(tile.height, dy[row + 1] - y)))
                    out.paste(part, (x, y))
    # These are the exact four fixed regions a Theme must preserve.
    for x, y, tx, ty, cw, ch in [(0, 0, 0, 0, left, top),
            (im.width-right, 0, w-right, 0, right, top),
            (0, im.height-bottom, 0, h-bottom, left, bottom),
            (im.width-right, im.height-bottom, w-right, h-bottom, right, bottom)]:
        assert im.crop((x, y, x+cw, y+ch)).tobytes() == out.crop((tx, ty, tx+cw, ty+ch)).tobytes()
    validate(out)
    return out


def controls():
    source = ["Inventory interface/EMPTY_SLOT.png", "Inventory interface/USING_SLOT.png"]
    states = {
        "panel": ("#241e1e", "#58534a", "#302b2b", False, False),
        "panel_inset": ("#080707", "#302b2b", "#211818", True, False),
        "button_normal": ("#302b2b", "#726650", "#58534a", False, False),
        "button_hover": ("#443830", "#d4ccab", "#726650", False, True),
        "button_pressed": ("#211818", "#8e886a", "#58534a", True, False),
        "button_disabled": ("#241e1e", "#443830", "#302b2b", False, False),
        "button_toggle_on": ("#302b2b", "#949974", "#58534a", True, True),
        "tooltip": ("#080707", "#928969", "#241e1e", False, False),
    }
    for name, values in states.items():
        save(name, framed(*values), source, name.replace("_", " "), [6, 6, 6, 6],
             "EMPTY alpha/chamfers and dotted detail, complete side border; palette remap. "
             + ("Interior bevel inset 1 source pixel." if values[3] else "Selected outline from USING." if values[4] else ""))
    # Cut a narrow horizontal frame from top/bottom and left/right pack material.
    panel = Image.open(OUT / "panel.png").convert("RGBA")
    track = blank((32, 6))
    for y in range(6):
        for x in range(32):
            # Sample the straight rim and plain center, omit slot's dotted ornament.
            sx, sy = (6, 0) if y == 0 else (6, 21) if y == 5 else (0, 8) if x in [0, 31] else (8, 8)
            track.putpixel((x, y), panel.getpixel((sx, sy)))
    for name in ["slider_track", "bar_background"]:
        save(name, track, source, name.replace("_", " "), [2]*4, "Cut/repeat EMPTY frame strips into 32x6 well.")
    for name, tint in [("slider_fill", "#928969"), ("bar_fill", "#949974")]:
        fill = blank((8, 4)); d = ImageDraw.Draw(fill)
        d.rectangle((0, 0, 7, 3), fill=color(tint)); d.line((0, 0, 7, 0), fill=color("#d4ccab"))
        d.line((0, 3, 7, 3), fill=color("#58534a"))
        save(name, fill, ["UI Elements/Zombie-Tileset---_0514_Capa-517.png"],
             name.replace("_", " "), [1]*4, "Battery material colours extended to a flat pixel strip.")
    for name, parent in [("slider_grabber", "button_normal"), ("slider_grabber_hover", "button_hover"),
                          ("checkbox_off", "button_normal"), ("checkbox_on", "button_toggle_on")]:
        im = Image.open(OUT / (parent + ".png")).convert("RGBA")
        if name.startswith("slider"):
            im = slice_image(im, (8, 12), [4, 6, 4, 6])
        else:
            im = slice_image(im, (12, 12), [6]*4)
        if name == "checkbox_on":
            d = ImageDraw.Draw(im)
            d.line([(3, 6), (5, 8), (9, 4)], fill=color("#080707"), width=3)
            d.line([(3, 5), (5, 7), (9, 3)], fill=color("#d4ccab"), width=1)
        save(name, im, source, name.replace("_", " "), processing="Fixed-size corner recombination; checkbox adds pixel check glyph.")


def pad(im):
    out = blank((16, 16)); out.paste(im, ((16-im.width)//2, (16-im.height)//2)); return out


def outlined_glyph(mask):
    outline = mask.filter(ImageFilter.MaxFilter(3))
    out = blank(mask.size); out.paste(color("#000000"), mask=outline)
    out.paste(color("#d4ccab"), mask=mask); return out


def icons():
    for name, n in [("icon_food", 329), ("icon_wood", 140), ("icon_scrap", 194), ("icon_survivors", 477)]:
        save(name, pad(pack_image(n)), [SOURCES[n].relative_to(PACK / "sprites").as_posix()],
             name.replace("_", " "), processing="Unchanged native sprite, centered on 16x16 transparent cell.")
    ammo = slot("SINGLE_AMMO_SLOT"); empty = slot("EMPTY_SLOT")
    isolated = blank(ammo.size)
    for y in range(ammo.height):
        for x in range(ammo.width):
            if ammo.getpixel((x, y)) != empty.getpixel((x, y)):
                isolated.putpixel((x, y), ammo.getpixel((x, y)))
    isolated = isolated.crop(isolated.getbbox())
    save("icon_ammo", pad(isolated), ["Inventory interface/SINGLE_AMMO_SLOT.png", "Inventory interface/EMPTY_SLOT.png"],
         "ammo cartridge", processing="Subtract EMPTY_SLOT to extract only cartridge pixels, no frame; centered at native size.")
    for name in ["icon_day", "icon_night", "icon_pause", "icon_play", "icon_fast", "icon_faster"]:
        size = (16, 16) if name in ["icon_day", "icon_night"] else (8, 8)
        mask = Image.new("L", size); d = ImageDraw.Draw(mask)
        if name == "icon_day":
            d.rectangle((6, 4, 9, 11), fill=255); d.rectangle((4, 6, 11, 9), fill=255)
            for a,b in [((7,1),(8,2)), ((7,13),(8,14)), ((1,7),(2,8)), ((13,7),(14,8))]: d.rectangle((*a,*b), fill=255)
        elif name == "icon_night":
            d.polygon([(7,2),(11,2),(9,4),(8,7),(9,10),(12,11),(10,13),(6,13),(3,10),(3,6)],fill=255)
        elif name == "icon_pause":
            d.rectangle((1,1,2,6),fill=255); d.rectangle((5,1,6,6),fill=255)
        elif name == "icon_play":
            d.polygon([(2,1),(6,3),(6,4),(2,6)],fill=255)
        elif name == "icon_fast":
            for x in [0,4]: d.polygon([(x,1),(x+2,3),(x+2,4),(x,6)],fill=255)
        else:
            for x in [0,3,6]: d.polygon([(x,2),(x+1,3),(x+1,4),(x,5)],fill=255)
        save(name, outlined_glyph(mask), ["Original hand-placed glyph; UI Elements palette/outline reference"],
             name.replace("_", " "), processing="Hand-placed binary mask and black one-pixel outline; pack cream fill.")


def text_image(text, size):
    font = ImageFont.truetype(str(FONT), size)
    bbox = font.getbbox(text)
    mask = Image.new("1", (bbox[2]-min(0,bbox[0])+2, bbox[3]-bbox[1]+2))
    ImageDraw.Draw(mask).text((1-min(0,bbox[0]), 1-bbox[1]), text, font=font, fill=1)
    im = blank(mask.size); im.paste(color("#d4ccab"), mask=mask); return im


def contact_sheet():
    # All art and samples are native -> exactly 4x NEAREST. Labels are review-only.
    sheet = Image.new("RGBA", (2600, 4700), color("#302b2b"))
    def label(text, x, y, size=16, scale=1):
        im = text_image(text, size); im = im.resize((im.width*scale, im.height*scale), Image.Resampling.NEAREST)
        sheet.alpha_composite(im, (x, y))
    def art(im, x, y):
        sheet.alpha_composite(im.resize((im.width*4, im.height*4), Image.Resampling.NEAREST), (x, y))
    label("T-108 / PACK UI KIT / ALL ART 4x NEAREST", 24, 20, 32)
    label("Native controls and states (no baked labels)", 24, 65, 20)
    for i, (name, data) in enumerate(ASSETS.items()):
        x=24+(i%7)*365; y=110+(i//7)*160
        label(name, x, y); art(Image.open(OUT / (name+".png")).convert("RGBA"), x, y+28)
        label(str(data["size"]), x+150, y+50)
    label("Pack reference pixels: EMPTY / USING / food / log / tire / player", 24, 775, 20)
    references=[slot("EMPTY_SLOT"),slot("USING_SLOT"),pack_image(329),pack_image(140),pack_image(194),pack_image(477)]
    for i, im in enumerate(references): art(im, 24+i*220, 825)
    label("9-slices: each at 200x48 and 400x300 SCREEN px; corners remain 4x native",24,950,20)
    slices=[(n,a) for n,a in ASSETS.items() if a["margins"]]
    for i,(name,data) in enumerate(slices):
        x=24+(i%3)*850; y=1010+(i//3)*385
        label(name+" / L,T,R,B "+str(data["margins"]),x,y)
        im=Image.open(OUT/(name+".png")).convert("RGBA")
        art(slice_image(im,(50,12),data["margins"]),x,y+40)
        art(slice_image(im,(100,75),data["margins"]),x+230,y+40)
    y=2610
    label("Pixelify Sans / binary raster / original pixel sizes shown at 4x for inspection",24,y,20)
    for size in [16,20,32,48]:
        y+=65; label(str(size)+" px",24,y)
        for sample in ["Night – dawn in 0:40", "Wooden Wall 5 wood"]:
            im=text_image(sample,size); art(im,160,y); y+=im.height*4+16
    label("Coverage: A-Z a-z 0-9 : , . ' ! ? - – ( ) / % + ×",24,y+25,20)
    validate(sheet)
    sheet.crop((0,0,2600,y+100)).convert("RGB").save(RUN/"contact_sheet.png")
    # Actual UI sizes, separate from the magnified review sheet.
    sample=Image.new("RGBA",(1500,350),color("#241e1e")); sy=20
    for size in [16,20,32,48]:
        im=text_image(str(size)+" px: Night – dawn in 0:40 / Wooden Wall 5 wood",size)
        sample.alpha_composite(im,(16,sy)); sy+=size+35
    validate(sample); sample.convert("RGB").save(RUN/"font_actual_sizes.png")


def main():
    RUN.mkdir(parents=True,exist_ok=True)
    controls(); icons()
    font=TTFont(FONT)
    required="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789: , .'!?-–()/%+×"
    missing=[c for c in required if ord(c) not in font.getBestCmap()]
    assert not missing,missing
    assert "SIL OPEN FONT LICENSE Version 1.1" in (FONT.parent/"OFL.txt").read_text()
    contact_sheet()
    manifest=dict(task="T-108", assets=ASSETS, font=dict(file=FONT.relative_to(ROOT).as_posix(),
        source="https://github.com/google/fonts/tree/main/ofl/pixelifysans", license="SIL OFL 1.1",
        sha256=hashlib.sha256(FONT.read_bytes()).hexdigest(), required_glyphs=required, missing_glyphs=missing))
    (PACK/"gapfill/ui_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    (RUN/"asset_validation.json").write_text(json.dumps(dict(png_count=len(ASSETS),
        palette="41 pack RGBs only",alpha="0 or 255", font_missing_glyphs=missing,
        corner_checks=len([a for a in ASSETS.values() if a["margins"]])*8),indent=2)+"\n")
    print(f"PASS: {len(ASSETS)} PNGs; pack palette/binary alpha; every 9-slice corner at both target sizes; font coverage/OFL")


if __name__ == "__main__":
    main()
