"""Build Siege Pixel from the shipped Pixelify Sans Regular instance.

Requires fontTools and Pillow. Run from any directory:
  python project/tools/make_siege_pixel_font.py --run-dir project/runs/T-130/a1

Only ASCII digits change. Source stroke expansion gives bounds (60, -12,
525, 631), rather than exact pixel edges. Anchor the strict 1000/11 grid
at (60, -12): seven rows end at 624 (7 units below the expanded source).
The baseline, OS/2 cap height, ascender and descender remain unchanged.
Shared pixel edges are cancelled: exteriors are clockwise, counters are
counter-clockwise, and no internal contour seams or overlaps remain.
"""

import argparse
import hashlib
import json
from pathlib import Path

from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT_DIR = ROOT / "game/assets/pixel/ui/font"
SOURCE = FONT_DIR / "pixelify_sans.ttf"
OUTPUT = FONT_DIR / "siege_pixel.ttf"
SAMPLES = (
    "0123456789 S s O o l I",
    "HP 80/80  15  500  58 85 S8 5S",
    "Nightfall in 1:05  Day 18  -8 +5",
)
# Top-to-bottom, five columns by seven rows; 0 has an isolated centre dot.
PIXELS = {
    "0": ("01110", "10001", "10001", "10101", "10001", "10001", "01110"),
    "1": ("00100", "01100", "00100", "00100", "00100", "00100", "01110"),
    "2": ("11110", "00001", "00001", "01110", "10000", "10000", "11111"),
    "3": ("11110", "00001", "00001", "01110", "00001", "00001", "11110"),
    "4": ("10001", "10001", "10001", "11111", "00001", "00001", "00001"),
    "5": ("11111", "10000", "10000", "11110", "00001", "00001", "11110"),
    "6": ("11110", "10000", "10000", "11111", "10001", "10001", "11111"),
    "7": ("11111", "00001", "00010", "00100", "00100", "00100", "00100"),
    "8": ("11111", "10001", "10001", "11111", "10001", "10001", "11111"),
    "9": ("11111", "10001", "10001", "11111", "00001", "00001", "01111"),
}


def outline(font, name):
    glyphs = font.getGlyphSet()
    pen = DecomposingRecordingPen(glyphs)
    glyphs[name].draw(pen)
    return pen.value


def grid_line(origin, index, upem):
    # Integer arithmetic: nearest 11-per-em boundary, no accumulated rounding.
    return origin + (index * upem + 5) // 11


def draw_digit(pattern, x_lines, y_lines):
    # Union the squares on the integer pixel lattice before mapping to units.
    # Cancelling shared reverse edges also produces correctly wound counters.
    edges = set()
    for row, pixels in enumerate(pattern):
        for column, pixel in enumerate(pixels):
            if pixel == "0":
                continue
            x, y = column, 6 - row
            corners = ((x, y), (x, y + 1), (x + 1, y + 1), (x + 1, y))
            for start, end in zip(corners, corners[1:] + corners[:1]):
                if (end, start) in edges:
                    edges.remove((end, start))
                else:
                    edges.add((start, end))
    directions = {(1, 0): 0, (0, 1): 1, (-1, 0): 2, (0, -1): 3}

    def direction(start, end):
        return directions[(end[0] - start[0], end[1] - start[1])]

    pen = TTGlyphPen(None)
    while edges:
        start, end = min(edges)
        contour = [start]
        edges.remove((start, end))
        previous, current = start, end
        while current != start:
            contour.append(current)
            candidates = [edge for edge in edges if edge[0] == current]
            assert candidates, "Open pixel boundary"
            incoming = direction(previous, current)
            # Right turn first keeps diagonally touching squares independent.
            rank = {3: 0, 0: 1, 1: 2, 2: 3}
            edge = min(candidates, key=lambda e: rank[(direction(*e) - incoming) % 4])
            edges.remove(edge)
            previous, current = edge
        corners = [p for i, p in enumerate(contour)
                   if direction(contour[i - 1], p) != direction(p, contour[(i + 1) % len(contour)])]
        area = sum(a[0] * b[1] - b[0] * a[1]
                   for a, b in zip(corners, corners[1:] + corners[:1]))
        assert area != 0
        points = [(x_lines[x], y_lines[y]) for x, y in corners]
        pen.moveTo(points[0])
        for point in points[1:]:
            pen.lineTo(point)
        pen.closePath()
    return pen.glyph()


def build_font():
    original = TTFont(SOURCE, recalcTimestamp=False)
    assert original["head"].unitsPerEm == 1000
    source = instantiateVariableFont(original, {"wght": 400}, inplace=False)
    font = instantiateVariableFont(
        TTFont(SOURCE, recalcTimestamp=False), {"wght": 400}, inplace=False
    )
    cmap = source.getBestCmap()
    digit_names = {cmap[ord(c)] for c in PIXELS}
    measured = {}
    for char in "0123456789SOIl":
        glyph = source["glyf"][cmap[ord(char)]]
        glyph.recalcBounds(source["glyf"])
        coordinates, _, _ = glyph.getCoordinates(source["glyf"])
        measured[char] = {
            "bounds": [glyph.xMin, glyph.yMin, glyph.xMax, glyph.yMax],
            "advance_lsb": list(source["hmtx"][cmap[ord(char)]]),
            "x_positions": sorted({x for x, _ in coordinates}),
            "y_positions": sorted({y for _, y in coordinates}),
        }
    x_origin, y_origin, _, source_top = measured["0"]["bounds"]
    upem = font["head"].unitsPerEm
    rows = round((source_top - y_origin) * 11 / upem)
    assert rows == 7
    x_lines = [grid_line(x_origin, i, upem) for i in range(6)]
    y_lines = [grid_line(y_origin, i, upem) for i in range(rows + 1)]
    advance = source["hmtx"][cmap[ord("0")]][0]
    for char, pattern in PIXELS.items():
        name = cmap[ord(char)]
        font["glyf"][name] = draw_digit(pattern, x_lines, y_lines)
        glyph = font["glyf"][name]
        glyph.recalcBounds(font["glyf"])
        font["hmtx"][name] = (advance, glyph.xMin)
    # Name all platforms consistently; retain the upstream OFL ID 13/14.
    names = font["name"]
    replacements = {
        0: names.getDebugName(0) + "\nDigits modified 2026 for Zombie Siege",
        1: "Siege Pixel", 2: "Regular", 3: "1.000;NONE;SiegePixel-Regular",
        4: "Siege Pixel Regular", 6: "SiegePixel-Regular",
        16: "Siege Pixel", 17: "Regular",
    }
    for name_id, value in replacements.items():
        names.removeNames(nameID=name_id)
        for platform, encoding, language in ((3, 1, 0x409), (1, 0, 0)):
            names.setName(value, name_id, platform, encoding, language)
    names.removeNames(nameID=25)
    if "STAT" in font:
        del font["STAT"]
    font.recalcTimestamp = False
    font.save(OUTPUT)
    result = TTFont(OUTPUT, recalcTimestamp=False)
    assert not ({"fvar", "gvar", "avar", "HVAR", "MVAR", "VVAR"} & set(result.keys()))
    assert result["name"].getDebugName(1) == "Siege Pixel"
    assert result["name"].getDebugName(4) == "Siege Pixel Regular"
    assert result["name"].getDebugName(6) == "SiegePixel-Regular"
    for name_id in (13, 14):
        assert result["name"].getDebugName(name_id) == source["name"].getDebugName(name_id)
    # Check serialized output, including decomposed composite glyphs.
    differences = [name for name in source.getGlyphOrder()
                   if name not in digit_names and outline(source, name) != outline(result, name)]
    assert not differences, differences
    assert all(result["hmtx"][n] == source["hmtx"][n]
               for n in source.getGlyphOrder() if n not in digit_names)
    for name in digit_names:
        glyph = result["glyf"][name]
        coordinates, _, flags = glyph.getCoordinates(result["glyf"])
        assert all(x in x_lines and y in y_lines for x, y in coordinates), name
        assert all(flag & 1 for flag in flags), name  # straight pixel edges
        assert glyph.yMin == y_origin and glyph.yMax == y_lines[-1]
        assert result["hmtx"][name] == (advance, glyph.xMin)
    assert len({result["hmtx"][n][0] for n in digit_names}) == 1
    assert result["OS/2"].sCapHeight == source["OS/2"].sCapHeight
    assert (result["hhea"].ascent, result["hhea"].descent) == (
        source["hhea"].ascent, source["hhea"].descent)
    report = {
        "source_instance": "Pixelify Sans wght=400", "family": "Siege Pixel",
        "static": True, "units_per_em": upem, "grid_pixels_per_em": 11,
        "grid_origin": [x_origin, y_origin], "grid_x": x_lines, "grid_y": y_lines,
        "source_measurements": measured, "digit_advance": advance,
        "digit_bounds_y": [y_origin, y_lines[-1]], "source_top_snap_units": y_lines[-1] - source_top,
        "cap_height_metadata": result["OS/2"].sCapHeight,
        "non_digit_outlines_checked": len(source.getGlyphOrder()) - 10,
        "non_digit_outline_differences": len(differences), "non_digit_metrics_differences": 0,
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "output_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "digit_patterns": PIXELS,
    }
    print(f"Static Siege Pixel: 10 grid-aligned digits, advance {advance}; "
          f"{report['non_digit_outlines_checked']} non-digit outlines checked, ZERO differences.")
    print(f"Measured source cap edge {source_top}; strict grid edge {y_lines[-1]}; "
          f"baseline {y_origin}, cap-height metric {result['OS/2'].sCapHeight} unchanged.")
    return report


def sample_block(path, size):
    font = ImageFont.truetype(str(path), size)
    ascent, descent = font.getmetrics()
    step = ascent + descent + 6
    width = max(int(font.getlength(text)) for text in SAMPLES) + 24
    block = Image.new("RGB", (width, step * len(SAMPLES) + 8), "#221d23")
    draw = ImageDraw.Draw(block)
    draw.fontmode = "1"  # FreeType monochrome, no AA or resampling.
    for index, text in enumerate(SAMPLES):
        draw.text((10, 4 + ascent + index * step), text, anchor="ls", font=font, fill="#e5e5d5")
    assert {color for _, color in block.getcolors()} <= {(34, 29, 35), (229, 229, 213)}
    return block


def check_rasters():
    """Verify the key ambiguities and two enclosed 8 counters at every size."""
    results = []
    for size in (11, 22, 33, 44):
        font = ImageFont.truetype(str(OUTPUT), size)

        def raster(char):
            mask = Image.new("1", (size * 2, size * 2))
            draw = ImageDraw.Draw(mask)
            draw.fontmode = "1"
            draw.text((2, size), char, anchor="ls", font=font, fill=1)
            return mask

        for left, right in (("5", "S"), ("8", "S"), ("0", "O"),
                            ("1", "l"), ("1", "I"), ("3", "8"),
                            ("6", "8"), ("9", "8")):
            assert raster(left).tobytes() != raster(right).tobytes(), (size, left, right)
        mask = raster("8")
        empty = {(x, y) for y in range(mask.height) for x in range(mask.width)
                 if mask.getpixel((x, y)) == 0}
        counters = 0
        while empty:
            seed = empty.pop()
            queue = [seed]
            touches_edge = False
            while queue:
                x, y = queue.pop()
                touches_edge |= x in (0, mask.width - 1) or y in (0, mask.height - 1)
                for point in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if point in empty:
                        empty.remove(point)
                        queue.append(point)
            counters += not touches_edge
        assert counters == 2, (size, counters)
        results.append({"size_px": size, "distinct_pairs_checked": 8, "eight_closed_counters": counters})
    print("Monochrome raster checks: all ambiguous pairs distinct; 8 has two closed counters at 11/22/33/44 px.")
    return results


def write_sheets(run_dir):
    annotation = ImageFont.load_default(size=14)
    pairs = [(size, sample_block(SOURCE, size), sample_block(OUTPUT, size))
             for size in (11, 22, 33, 44)]
    crops = [pairs[0][1].resize((pairs[0][1].width * 4, pairs[0][1].height * 4),
                              Image.Resampling.NEAREST),
             pairs[0][2].resize((pairs[0][2].width * 4, pairs[0][2].height * 4),
                              Image.Resampling.NEAREST)]
    width = max(image.width for _, old, new in pairs for image in (old, new))
    width = max(width, *(crop.width for crop in crops)) + 32
    height = 50 + sum(old.height + new.height + 64 for _, old, new in pairs)
    height += sum(crop.height + 40 for crop in crops) + 24
    sheet = Image.new("RGB", (width, height), "#39343d")
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 14), "T-130 | Pixelify Sans Regular vs Siege Pixel | native 1x monochrome TTF renders",
              font=annotation, fill="white")
    y = 48
    for size, old, new in pairs:
        for label, block in (("OLD - Pixelify Sans", old), ("NEW - Siege Pixel", new)):
            draw.text((16, y), f"{size} px | {label} | 1x", font=annotation, fill="white")
            sheet.paste(block, (16, y + 22))
            y += block.height + 32
    for label, crop in zip(("OLD", "NEW"), crops):
        draw.text((16, y), f"11 px {label} - nearest 4x inspection crop", font=annotation, fill="white")
        sheet.paste(crop, (16, y + 24))
        crop.save(run_dir / f"digits_11px_{label.lower()}_x4.png")
        y += crop.height + 40
    sheet.save(run_dir / "digits_sheet.png")
    contact = Image.new("RGB", (max(700, pairs[1][2].width + 32), 330), "#221d23")
    d = ImageDraw.Draw(contact)
    d.text((16, 12), "Siege Pixel 22 px + existing Ittai Manero UI references (nearest 4x)",
           font=annotation, fill="white")
    contact.paste(pairs[1][2], (16, 40))
    references = ["panel.png", "button_normal.png", "icon_wood.png", "icon_scrap.png"]
    x = 16
    for filename in references:
        path = ROOT / "game/assets/pixel/ui" / filename
        if not path.exists():
            continue
        with Image.open(path) as asset:
            image = asset.convert("RGBA")
            image = image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST)
            contact.paste(image, (x, 175), image)
            d.text((x, 310), filename, font=annotation, fill="white")
            x += max(image.width + 24, 135)
    contact.save(run_dir / "contact_sheet.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, default=ROOT / "project/runs/T-130/a1")
    args = parser.parse_args()
    run_dir = args.run_dir.resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    report = build_font()
    report["raster_checks"] = check_rasters()
    write_sheets(run_dir)
    (run_dir / "font_validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
