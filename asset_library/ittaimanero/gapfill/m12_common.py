"""T-224 native-pixel helpers; never resample shipping sources."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
PACK = ROOT / 'asset_library/ittaimanero'
OUT = ROOT / 'game/assets/pixel'
PALETTE = {tuple(bytes.fromhex(c[1:])) for c in json.loads((PACK/'palette.json').read_text())}
SOURCES = {int(p.stem.rsplit('-', 1)[1]): p for p in (PACK/'sprites').rglob('*Capa-*.png')}
ASSETS = {}

def color(hexcode):
    rgb = tuple(bytes.fromhex(hexcode.lstrip('#')))
    assert rgb in PALETTE
    return (*rgb, 255)

def blank(size):
    return Image.new('RGBA', size)

def load(n):
    return Image.open(SOURCES[n]).convert('RGBA')

def remap(im, mapping):
    result = im.copy()
    swaps = {color(k): color(v) for k, v in mapping.items()}
    result.putdata([swaps.get(p, p) for p in im.get_flattened_data()])
    return result

def save(name, im, ids, processing):
    pixels = list(im.get_flattened_data())
    assert {p[3] for p in pixels} <= {0, 255}, name
    assert {p[:3] for p in pixels if p[3]} <= PALETTE, name
    path = OUT / (name + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    ASSETS[name] = dict(file=path.relative_to(ROOT).as_posix(), size=list(im.size),
        sources=[SOURCES[n].relative_to(ROOT).as_posix() for n in ids],
        processing=processing, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    return im
