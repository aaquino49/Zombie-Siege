"""Generate nearest-neighbour 2x copies of native pixel UI textures.

Usage: python asset_library/ittaimanero/gapfill/ui_x2.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
UI_DIR = ROOT / "game/assets/pixel/ui"
OUT_DIR = UI_DIR / "x2"


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    count = 0
    for p in sorted(UI_DIR.glob("*.png")):
        if p.is_file():
            im = Image.open(p)
            w, h = im.size
            im_2x = im.resize((w * 2, h * 2), Image.NEAREST)
            out_file = OUT_DIR / p.name
            im_2x.save(out_file)
            count += 1
            print(f"Wrote {out_file.relative_to(ROOT)}: ({w}x{h}) -> ({w*2}x{h*2})")
    print(f"Generated {count} 2x UI textures in {OUT_DIR.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
