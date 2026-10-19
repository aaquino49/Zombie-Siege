"""Native-pixel helpers shared by T-118's six asset recipes (Python + Pillow)."""
from pathlib import Path
import hashlib
import json
import sys

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
PACK = ROOT / "asset_library/ittaimanero"
OUT = ROOT / "game/assets/pixel"
RUN = ROOT / "project/runs/T-118/a1"
PALETTE = {tuple(bytes.fromhex(c[1:])) for c in json.loads((PACK / "palette.json").read_text())}
SOURCES = {int(p.stem.rsplit("-", 1)[1]): p for p in (PACK / "sprites").rglob("*Capa-*.png")}
ASSETS = {}
DIRS = ("down", "left", "up", "right")


def colour(hex_colour):
    rgb = tuple(bytes.fromhex(hex_colour.lstrip("#")))
    assert rgb in PALETTE, hex_colour
    return (*rgb, 255)


def canvas(size):
    return Image.new("RGBA", size)


def load(n):
    return Image.open(SOURCES[n]).convert("RGBA")


def curated(name):
    return Image.open(OUT / (name + ".png")).convert("RGBA")


def remap(im, mapping):
    out = im.copy()
    swaps = {colour(k): colour(v) if v else (0, 0, 0, 0) for k, v in mapping.items()}
    out.putdata([swaps.get(p, p) for p in im.get_flattened_data()])
    return out


def mirror(im):
    return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)


def strip(frames):
    w, h = frames[0].size
    assert all(im.size == (w, h) for im in frames)
    out = canvas((w * len(frames), h))
    for k, im in enumerate(frames):
        out.paste(im, (k * w, 0))
    return out


def cells(im, cell=(16, 16)):
    assert im.height == cell[1] and im.width % cell[0] == 0
    return [im.crop((x, 0, x + cell[0], cell[1])) for x in range(0, im.width, cell[0])]


def save(name, im, ids, processing, cell=None, **metadata):
    pixels = list(im.get_flattened_data())
    assert {p[:3] for p in pixels if p[3]} <= PALETTE, name
    assert {p[3] for p in pixels} <= {0, 255}, name
    assert any(p == (0, 0, 0, 255) for p in pixels), (name, "missing pack outline")
    path = OUT / (name + ".png")
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    ASSETS[name] = dict(file=path.relative_to(ROOT).as_posix(), size=list(im.size),
                        cell=list(cell or im.size), ids=ids,
                        sources=[SOURCES[n].relative_to(ROOT).as_posix() for n in ids],
                        processing=processing, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                        **metadata)
    print(f"PASS palette ({len(PALETTE)} colours), binary alpha: {name} {im.size}")
    return im
