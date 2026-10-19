"""T-143: rebuild wood/scrap icons from pack pixels with a thin cream rim.

Run this after ui_glyphs.py, then run ui_x2.py. Only these two native icons
are written. Original opaque pixel positions and black contours are retained.
"""
from collections import deque
from pathlib import Path
import json

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
PACK = ROOT / "asset_library/ittaimanero"
UI = ROOT / "game/assets/pixel/ui"
CREAM = (212, 204, 171, 255)  # #d4ccab: pack/UI text cream
SOURCES = {
    "icon_wood": "Trees/Zombie-Tileset---_0139_Capa-140.png",
    "icon_scrap": "Broken Cars and Tires/Zombie-Tileset---_0193_Capa-194.png",
}
SCRAP_LIFT = {
    # One step along the pack's existing warm material ramp, retaining black.
    (33, 24, 24): (71, 53, 44),  # #211818 -> #47352c
    (71, 53, 44): (119, 102, 78),  # #47352c -> #77664e
    (119, 102, 78): (146, 137, 105),  # #77664e -> #928969
}
NEIGHBORS = ((-1, 0), (1, 0), (0, -1), (0, 1))


def make_icon(name):
    source = Image.open(PACK / "sprites" / SOURCES[name]).convert("RGBA")
    icon = Image.new("RGBA", (16, 16))
    icon.paste(source, ((16 - source.width) // 2, (16 - source.height) // 2))
    original = icon.copy()
    # Flood only the exterior transparency; preserve enclosed tire openings.
    exterior = set()
    queue = deque((x, y) for y in range(16) for x in range(16)
                  if x in (0, 15) or y in (0, 15))
    while queue:
        x, y = queue.popleft()
        if (x, y) in exterior or original.getpixel((x, y))[3]:
            continue
        exterior.add((x, y))
        for dx, dy in NEIGHBORS:
            nx, ny = x + dx, y + dy
            if 0 <= nx < 16 and 0 <= ny < 16:
                queue.append((nx, ny))
    for y in range(16):
        for x in range(16):
            pixel = original.getpixel((x, y))
            if pixel[3]:
                if name == "icon_scrap" and pixel[:3] in SCRAP_LIFT:
                    icon.putpixel((x, y), (*SCRAP_LIFT[pixel[:3]], 255))
            elif (x, y) in exterior and any(
                0 <= x + dx < 16 and 0 <= y + dy < 16
                and original.getpixel((x + dx, y + dy))[3]
                for dx, dy in NEIGHBORS
            ):
                icon.putpixel((x, y), CREAM)
    palette = {tuple(bytes.fromhex(c[1:]))
               for c in json.loads((PACK / "palette.json").read_text())}
    pixels = list(icon.get_flattened_data())
    assert {p[:3] for p in pixels if p[3]} <= palette
    assert {p[3] for p in pixels} <= {0, 255}
    return icon


def main():
    for name in SOURCES:
        image = make_icon(name)
        image.save(UI / f"{name}.png")
        print(f"Wrote {name}: 16x16, pack palette, binary alpha, 1px exterior rim")


if __name__ == "__main__":
    main()
