"""T-123 light ground / T-142 ragged, textured dirt. Python + Pillow, any cwd.

Rebuild from immutable pack sources, never from already recoloured outputs.
--candidates-only writes the day/night comparison without changing game assets.
--review writes T-142 3x3 seam contexts and native before/after sheets.
"""
from pathlib import Path
import argparse
import hashlib
import io
import json
import re
import sys

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
PACK = ROOT / "asset_library/ittaimanero"
OUT = ROOT / "game/assets/pixel"
RUN = ROOT / "project/runs/T-123/a1"
GROUND = "#949974"
SPECKLE = "#8e886a"
DIRT = "#47352c"
DIRT_DETAIL = "#504433"
PEBBLE = "#77664e"
# Palindromic, equal endpoints: every orientation joins at a 3px inset.
# Long runs of two pixels keep the hand-placed edge calm at 4x scale.
PROFILE = (3, 3, 2, 2, 4, 5, 4, 3, 3, 4, 5, 4, 2, 2, 3, 3)
CANDIDATES = (("#77664e", "#7f765d"), ("#83775b", "#8e886a"), (GROUND, SPECKLE))
SUFFIXES = ("center", "edge_n", "edge_e", "edge_s", "edge_w", "outer_ne",
            "outer_nw", "outer_se", "outer_sw", "inner_ne", "inner_nw", "inner_se", "inner_sw")
MAPPING = json.loads((PACK / "mapping_manifest.json").read_text(encoding="utf-8"))
SOURCES = {n: ROOT / p for row in MAPPING for n, p in zip(row["ids"], row["sources"])}
PALETTE = {tuple(bytes.fromhex(c[1:])) for c in json.loads((PACK / "palette.json").read_text())}
PROCESSING = {}


def rgba(hex_color):
    return tuple(bytes.fromhex(hex_color.lstrip("#"))) + (255,)


def load(n):
    source = Image.open(SOURCES[n]).convert("RGBA")
    assert source.size == (16, 16), (n, source.size)
    return source


def dirt_cell(suffix, grass, variant=0):
    """Shared border masks; fixed interior marks, with no RNG or edge specks."""
    masks = {side: set() for side in "nesw"}
    for y in range(16):
        for x in range(16):
            for side, distance, along in (("n", y, x), ("e", 15-x, y),
                                          ("s", 15-y, x), ("w", x, y)):
                if distance < PROFILE[along]:
                    masks[side].add((x, y))
    outside = set()
    if suffix.startswith(("edge_", "outer_")):
        for side in suffix.split("_")[1]:
            outside |= masks[side]
    elif suffix.startswith("inner_"):
        a, b = suffix.split("_")[1]
        outside = masks[a] & masks[b]
    im = Image.new("RGBA", (16, 16), rgba(DIRT))
    for p in outside:
        im.putpixel(p, grass.getpixel(p))
    # A broken one-pixel inner rim softens the boundary without outlining it.
    rim = sorted((x, y) for y in range(1, 15) for x in range(1, 15)
                 if (x, y) not in outside and any((x+dx, y+dy) in outside
                 for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0))))
    marks = {p: DIRT_DETAIL for p in rim if (p[0]+p[1]) % 4 < 2}
    marks = dict(list(marks.items())[:8])
    specks = ((4, 7), (5, 7), (10, 4), (11, 10), (7, 12), (8, 12), (3, 11), (12, 6))
    pebbles = ((7, 5), (8, 5), (10, 12))
    if variant:
        specks = tuple((15-x, 15-y) for x, y in specks)
        pebbles = ((6, 10), (7, 10), (12, 3))
    # Leave border texels and the ground untouched; at most 10% of dirt pixels.
    budget = (256-len(outside)) // 10
    for p, color in [(p, PEBBLE) for p in pebbles] + [(p, DIRT_DETAIL) for p in specks]:
        if p not in outside and len(marks) < budget:
            marks[p] = color
    for p, color in marks.items():
        im.putpixel(p, rgba(color))
    assert 0 < len(marks) <= budget
    return im


def recipe(ground=GROUND, speckle=SPECKLE):
    """Preserve ground details; replace only the authored dirt/path pixels."""
    assets = {}
    for name, n in [(f"grass_{i}", n) for i, n in enumerate(range(78, 82), 1)] + [
            ("flowers_1", 118), ("flowers_2", 218)]:
        im = load(n)
        remap = {rgba("#47352c"): rgba(ground), rgba("#77664e"): rgba(speckle)}
        im.putdata([remap.get(p, p) for p in im.get_flattened_data()])
        key = "terrain/" + name
        assets[key] = im
        PROCESSING[key] = (f"T-123: source ground #47352c -> {ground}; source speckle #77664e -> {speckle}; "
                           "preserve black blades/flowers and petal pixels; native 16x16.")
    for name in ("dirt", "dirt_2"):
        im = dirt_cell("center", assets["terrain/grass_1"], int(name == "dirt_2"))
        key = "terrain/" + name
        assets[key] = im
        PROCESSING[key] = f"T-142: dark {DIRT}; fixed sparse {DIRT_DETAIL} specks and {PEBBLE} pebbles, <=10% of dirt pixels."
    boundaries = []
    for suffix in SUFFIXES:
        im = dirt_cell(suffix, assets["terrain/grass_1"])
        key = "terrain/path_" + suffix
        assets[key] = im
        PROCESSING[key] = (f"T-142: {DIRT} dirt / {ground} ground; shared 2-5px stepped inset, "
                           f"3px matching endpoints; broken {DIRT_DETAIL} inner rim, sparse specks and {PEBBLE} pebbles <=10%.")
        boundaries.append(im)
    atlas = Image.new("RGBA", (208, 16))
    for i, im in enumerate(boundaries):
        atlas.paste(im, (16 * i, 0))
    assets["terrain/path_boundary"] = atlas
    PROCESSING["terrain/path_boundary"] = "T-142: exact 13 textured native cells in unchanged PathTiles.SUFFIXES order: " + ", ".join(SUFFIXES)
    return assets


def build():
    assets = recipe()
    manifest = []
    for name, im in assets.items():
        pixels = list(im.get_flattened_data())
        assert {p[:3] for p in pixels} <= PALETTE, name
        assert {p[3] for p in pixels} == {255}, name
        dest = OUT / (name + ".png")
        assert Image.open(dest).size == im.size, name
        buffer = io.BytesIO()
        im.save(buffer, format="PNG")
        # Preserve untouched grass/flower files and avoid pointless reimports.
        if dest.read_bytes() != buffer.getvalue():
            dest.write_bytes(buffer.getvalue())
        short = name.split("/")[-1]
        if short.startswith("grass_"):
            ids = [77 + int(short[-1])]
        elif short.startswith("flowers_"):
            ids = [118 if short.endswith("1") else 218]
        elif short.startswith("dirt"):
            ids = [66, 68, 78]
        elif short == "path_boundary":
            ids = [66, 68, 69, 71, 72, 74, 75, 78]
        else:
            ids = next(r["ids"] for r in MAPPING if r["entity"] == short)
        manifest.append(dict(file=dest.relative_to(ROOT).as_posix(), size=list(im.size),
                             cell=[16, 16], ids=ids, sources=[SOURCES[n].relative_to(ROOT).as_posix() for n in ids],
                             processing=PROCESSING[name], sha256=hashlib.sha256(dest.read_bytes()).hexdigest()))
    (PACK / "gapfill/terrain_manifest.json").write_text(json.dumps(dict(
        ground=GROUND, ground_speckle=SPECKLE, dirt=DIRT, dirt_speckle=DIRT_DETAIL,
        dirt_pebble=PEBBLE, edge_profile=list(PROFILE), texture_max_fraction=0.1,
        palette_exact=True, binary_alpha=True, assets=manifest), indent=2) + "\n", encoding="utf-8")
    documents()
    print(f"PASS: rebuilt {len(assets)} native palette-exact opaque PNGs; atlas 208x16.")


def documents():
    path = ROOT / "game/assets/ASSET_INDEX.md"
    original = path.read_bytes().decode("utf-8")
    newline = "\r\n" if original.endswith("\r\n") else "\n"
    text = original
    for name, processing in PROCESSING.items():
        prefix = f"| `pixel/{name}.png` |"
        lines = text.splitlines(keepends=True)
        for i, line in enumerate(lines):
            if line.startswith(prefix):
                ending = "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""
                fields = line.rstrip("\r\n").split("|")
                fields[-2] = " " + processing + " "
                lines[i] = "|".join(fields) + ending
                break
        else:
            raise AssertionError("Missing asset index row: " + name)
        text = "".join(lines)
    marker = "## T-142 ragged dirt paths and patches"
    section = (marker + "\n\n"
             "Rebuild with `python asset_library/ittaimanero/gapfill/terrain_light.py`. "
             "The 16 dirt/path PNGs use deterministic stepped edges, a broken inner rim and sparse pebbles/specks "
             "(at most 10% of dirt pixels). Ground, flower and tuft pixels are unchanged. "
             "The 208x16 atlas retains its 13-cell order; palette, dimensions and SHA-256 hashes are in "
             "`asset_library/ittaimanero/gapfill/terrain_manifest.json`. "
             "`--review --run-dir project/runs/T-142/a1` writes 3x3 seam contexts beside pack tiles and "
             "native before/after default and night sheets.\n")
    # Replace this task's section only: later font/zombie sections must survive reruns.
    text = replace_section(text, marker, section.replace("\n", newline))
    path.write_bytes(text.encode("utf-8"))
    path = ROOT / "CREDITS.md"
    original = path.read_bytes().decode("utf-8")
    newline = "\r\n" if original.endswith("\r\n") else "\n"
    section = (marker + "\n\n"
             "Ittai Manero, Zombie Apocalypse Tileset (itch.io), under the existing pack terms. "
             "Codex hand-placed stepped dirt boundaries, a broken inner rim and quiet earth texture "
             "exclusively within the pack palette. Ground details and other art are preserved. "
             "Reproducible recipe: `asset_library/ittaimanero/gapfill/terrain_light.py`; "
             "sources and output hashes: `terrain_manifest.json`.\n")
    text = replace_section(original, marker, section.replace("\n", newline))
    path.write_bytes(text.encode("utf-8"))


def replace_section(text, marker, section):
    newline = "\r\n" if "\r\n" in text else "\n"
    start = text.find(marker)
    if start < 0:
        return text.rstrip("\r\n") + newline * 2 + section
    end = text.find(newline + "## ", start + len(marker))
    return text[:start] + section + (text[end:] if end >= 0 else "")


def tint(im, constant="NIGHT_COLOR"):
    text = (ROOT / "game/scripts/world/day_night_tint.gd").read_text()
    match = re.search(r"const " + constant + r": Color = Color\(([^)]+)\)", text)
    factors = [float(x.strip()) for x in match[1].split(",")]
    out = im.convert("RGB")
    out.putdata([tuple(round(p[i] * factors[i]) for i in range(3)) for p in out.get_flattened_data()])
    return out


def curated(name):
    im = Image.open(OUT / (name + ".png")).convert("RGBA")
    return im.crop((0, 0, 16, 16)) if name.startswith(("characters/", "zombies/")) else im


def patch(assets):
    """12x8 source-tile mockup with a two-tile wide bending path."""
    im = Image.new("RGBA", (192, 128))
    path = {(x, y) for x in range(9) for y in (4, 5)} | {(x, y) for x in (7, 8) for y in range(4, 8)}
    sides = ((0, -1, "n"), (1, 0, "e"), (0, 1, "s"), (-1, 0, "w"))
    diagonals = ((1, -1, "ne"), (-1, -1, "nw"), (1, 1, "se"), (-1, 1, "sw"))
    for y in range(8):
        for x in range(12):
            name = "grass_1" if (x * 7 + y * 11) % 9 < 6 else "grass_" + str(2 + (x + y) % 3)
            if (x, y) in path:
                missing = {s for dx, dy, s in sides if (x + dx, y + dy) not in path}
                suffix = "center"
                if len(missing) == 1:
                    suffix = "edge_" + next(iter(missing))
                elif len(missing) == 2:
                    suffix = next(("outer_" + s for dx, dy, s in diagonals if set(s) == missing), "center")
                elif not missing:
                    corners = [s for dx, dy, s in diagonals if (x + dx, y + dy) not in path]
                    if len(corners) == 1:
                        suffix = "inner_" + corners[0]
                name = "path_" + suffix
            im.paste(assets["terrain/" + name], (16 * x, 16 * y))
    # Two bush interiors and outlines, trees, both rock shapes, scrap, fences,
    # earth-wall material, and units on both materials. No sprite recolours.
    sprites = [("props/tree_1", 1, 3), ("props/tree_2", 10, 3),
               ("props/bush_1", 3, 2), ("props/bush_4", 9, 6),
               ("props/rock_a", 5, 2), ("props/rock_b", 2, 7),
               ("props/scrap_1", 7, 2), ("props/scrap_2", 4, 7),
               ("buildings/fence_h", 4, 4), ("buildings/wall_earth_h", 6, 4),
               ("characters/survivor_blue_walk_down", 4, 3), ("zombies/walker_walk_down", 8, 3),
               ("characters/player_walk_down", 3, 5), ("zombies/brute_walk_down", 6, 5),
               ("terrain/tuft_1", 0, 7), ("terrain/tuft_2", 11, 7)]
    for name, x, feet_y in sprites:
        sprite = curated(name)
        im.alpha_composite(sprite, (x * 16, feet_y * 16 - sprite.height))
    return im.convert("RGB")


def candidates():
    RUN.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGB", (1584, 2128), "#242424")
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 18)
    draw = ImageDraw.Draw(sheet)
    for i, (base, detail) in enumerate(CANDIDATES):
        y = 16 + i * 704
        scene = patch(recipe(base, detail))
        night = tint(scene)
        draw.text((16, y), f"{'ABC'[i]} ground {base} / speckle {detail} / dirt {DIRT}  | DAY 4x", font=font, fill="white")
        draw.text((800, y), "NIGHT 4x: NIGHT_COLOR = (0.42, 0.48, 0.72)", font=font, fill="white")
        sheet.paste(scene.resize((768, 512), Image.Resampling.NEAREST), (16, y + 32))
        sheet.paste(night.resize((768, 512), Image.Resampling.NEAREST), (800, y + 32))
        sheet.paste(scene, (16, y + 552)); sheet.paste(night, (800, y + 552))
        draw.text((224, y + 565), "DAY 1x native source", font=font, fill="white")
        draw.text((1008, y + 565), "NIGHT 1x native source", font=font, fill="white")
    sheet.save(RUN / "candidates.png")


def review(run_dir):
    """Each cell sits at the centre of a valid 3x3 autotile neighbourhood."""
    run_dir.mkdir(parents=True, exist_ok=True)
    assets = recipe()
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 16)
    sheet = Image.new("RGB", (1536, 1260), "#242424")
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 10), "T-142: all 13 cells in valid 3x3 contexts / 6x NEAREST / centre cell named", font=font, fill="white")
    checks = 0
    sides = ((0, -1, "n"), (1, 0, "e"), (0, 1, "s"), (-1, 0, "w"))
    diagonals = ((1, -1, "ne"), (-1, -1, "nw"), (1, 1, "se"), (-1, 1, "sw"))
    dirt_colors = {rgba(c) for c in (DIRT, DIRT_DETAIL, PEBBLE)}
    for i, target in enumerate(SUFFIXES):
        def is_grass(x, y):
            if target == "center":
                return False
            kind, corner = target.split("_")
            flags = {"n": y < 0, "e": x > 0, "s": y > 0, "w": x < 0}
            return all(flags[c] for c in corner) if kind == "inner" else any(flags[c] for c in corner)
        tiles = {}
        names = {}
        for y in range(-1, 2):
            for x in range(-1, 2):
                name = "grass_1"
                if not is_grass(x, y):
                    missing = {s for dx, dy, s in sides if is_grass(x+dx, y+dy)}
                    suffix = "center"
                    if len(missing) == 1:
                        suffix = "edge_" + next(iter(missing))
                    elif len(missing) == 2:
                        suffix = next(("outer_"+c for dx, dy, c in diagonals if set(c) == missing), "center")
                    elif not missing:
                        corners = [c for dx, dy, c in diagonals if is_grass(x+dx, y+dy)]
                        if len(corners) == 1:
                            suffix = "inner_" + corners[0]
                    name = "path_" + suffix
                tiles[x, y] = assets["terrain/"+name]
                names[x, y] = name
        assert names[0, 0] == "path_"+target
        context = Image.new("RGB", (48, 48))
        for (x, y), tile in tiles.items():
            context.paste(tile.convert("RGB"), ((x+1)*16, (y+1)*16))
            for dx, dy in ((1, 0), (0, 1)):
                other = tiles.get((x+dx, y+dy))
                if other is None or names[x, y] == "grass_1" or names[x+dx, y+dy] == "grass_1":
                    continue
                a = [tile.getpixel((15, k) if dx else (k, 15)) in dirt_colors for k in range(16)]
                b = [other.getpixel((0, k) if dx else (k, 0)) in dirt_colors for k in range(16)]
                assert a == b, (target, (x, y), (dx, dy))
                checks += 1
        px, py = 12 + (i % 5)*304, 44 + (i // 5)*330
        draw.text((px, py), target, font=font, fill="white")
        sheet.paste(context.resize((288, 288), Image.Resampling.NEAREST), (px, py+26))
    draw.text((12, 1040), "Pack references: Capa 78 ground / 68 path / 72 corner; existing ground and props", font=font, fill="white")
    donors = [load(n) for n in (78, 68, 72)] + [curated(n) for n in ("terrain/grass_1", "props/bush_1", "zombies/walker_walk_down")]
    for i, tile in enumerate(donors):
        tile = tile.resize((tile.width*4, tile.height*4), Image.Resampling.NEAREST)
        sheet.paste(tile, (12+i*160, 1074), tile)
    draw.text((12, 1210), f"PASS: {checks} dirt-to-dirt border mask joins; all 13 centre cells verified; no resampled art", font=font, fill="white")
    sheet.save(run_dir / "contact_sheet.png")
    for scenario in ("default", "night"):
        comparison = Image.new("RGB", (2560, 760), "#242424")
        caption = ImageDraw.Draw(comparison)
        caption.text((12, 12), scenario + ": BEFORE (left) / AFTER (right), native 1280x720", font=font, fill="white")
        for x, prefix in ((0, "before"), (1280, "after")):
            capture = Image.open(run_dir / f"{prefix}_{scenario}.png").convert("RGB")
            assert capture.size == (1280, 720)
            comparison.paste(capture, (x, 40))
        comparison.save(run_dir / f"before_after_{scenario}.png")
    print(f"PASS: contact sheet verifies all 13 cells and {checks} matching border masks.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidates-only", action="store_true")
    parser.add_argument("--review", action="store_true")
    parser.add_argument("--run-dir", type=Path, default=ROOT / "project/runs/T-142/a1")
    args = parser.parse_args()
    if args.candidates_only:
        candidates()
    else:
        build()
        if args.review:
            review(args.run_dir)
