from pathlib import Path
import hashlib
import json
import sys

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
PALETTE = {tuple(bytes.fromhex(c[1:])) for c in json.loads((ROOT / "asset_library/ittaimanero/palette.json").read_text())}
BUILDINGS = ROOT / "game/assets/pixel/buildings"
RUN = ROOT / "project/runs/T-120/a2"


def load(name: str) -> Image.Image:
    return Image.open(BUILDINGS / f"{name}.png").convert("RGBA")


def main() -> None:
    # Keep the native north-south fence rails, posts, and exact columns intact.
    vertical = load("fence_v")
    gate = load("gate_closed")
    image = vertical.copy()
    draw = ImageDraw.Draw(image)
    outline = gate.getpixel((3, 4))
    plank = gate.getpixel((3, 5))
    dark_post = vertical.getpixel((8, 7))
    light_edge = vertical.getpixel((7, 6))
    # Add upright hinge/latch posts at the ends, flanking the continuous center rail.
    for y0, y1 in ((1, 4), (11, 14)):
        draw.rectangle((6, y0, 8, y1), fill=outline)
        draw.rectangle((7, y0 + 1, 8, y1 - 1), fill=dark_post)
        draw.point((6, y0 + 1), fill=light_edge)
        draw.point((6, y1 - 1), fill=light_edge)
        draw.rectangle((12, y0, 14, y1), fill=outline)
        draw.rectangle((12, y0 + 1, 13, y1 - 1), fill=dark_post)
        draw.point((13, y0 + 1), fill=light_edge)
        draw.point((13, y1 - 1), fill=light_edge)
    # The closed leaf is a narrow vertical plank band. Preserve fence_v's x=9..11
    # north-south rail pixels exactly, so adjoining fence tiles remain continuous.
    for x in (6, 13):
        draw.line((x, 4, x, 11), fill=outline)
    for x in (7, 8, 12):
        draw.line((x, 5, x, 10), fill=plank)
    # Fine dark seams distinguish the upright boards without adding crossbars.
    draw.line((8, 5, 8, 10), fill=outline)
    draw.line((12, 5, 12, 10), fill=outline)
    for y in range(16):
        for x in range(9, 12):
            image.putpixel((x, y), vertical.getpixel((x, y)))

    pixels = list(image.get_flattened_data())
    assert image.size == (16, 16)
    assert {px[:3] for px in pixels if px[3]} <= PALETTE
    assert {px[3] for px in pixels} <= {0, 255}
    assert all(image.getpixel((x, y)) == vertical.getpixel((x, y)) for x in range(9, 12) for y in range(16))
    assert any(px == (0, 0, 0, 255) for px in pixels)
    out = BUILDINGS / "gate_closed_v.png"
    image.save(out)

    # 4x nearest-neighbour comparison sheet for gate, vertical fence, and new variant.
    sheet = Image.new("RGBA", (16 * 4 * 3 + 16 * 3, 16 * 4 + 24), (64, 64, 64, 255))
    for i, source in enumerate((load("fence_v"), load("gate_closed"), image)):
        enlarged = source.resize((64, 64), Image.Resampling.NEAREST)
        sheet.alpha_composite(enlarged, (8 + i * 80, 20))
    RUN.mkdir(parents=True, exist_ok=True)
    sheet.save(RUN / "contact_sheet.png")
    manifest = {
        "file": out.relative_to(ROOT).as_posix(),
        "size": [16, 16],
        "sources": ["pixel/buildings/gate_closed.png", "pixel/buildings/fence_v.png"],
        "pack_capa": [208, 210, 211, 212],
        "processing": "Recombined upright gate posts and narrow vertical leaf around the unchanged fence_v north-south rail columns; palette exact, binary alpha, no rotation.",
        "sha256": hashlib.sha256(out.read_bytes()).hexdigest(),
    }
    (RUN / "gate_vertical_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"PASS gate_closed_v.png: {image.size}, palette exact, binary alpha, center rail preserved")


if __name__ == "__main__":
    main()
