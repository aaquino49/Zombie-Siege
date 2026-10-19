"""T-102 native pack processing. Run from any directory with Python + Pillow.

Re-run safely: PNGs, index/credit sections and review artifacts are deterministic.
Use --check-imports after Godot import to verify lossless/no-mipmap/default Nearest.
No game code, raw pack copies, SpriteFrames or unused spare enemy are produced.
"""
from pathlib import Path
import argparse
import json
import sys
import textwrap

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw, ImageFont
from mapping_data import ROWS

ROOT = Path(__file__).resolve().parents[3]
PACK = ROOT / "asset_library/ittaimanero"
sys.path.insert(0, str(PACK / "gapfill"))
import terrain_light

OUT = ROOT / "game/assets/pixel"
RUN = ROOT / "project/runs/T-102/a1"
MANIFEST = json.loads((PACK / "mapping_manifest.json").read_text(encoding="utf-8"))
assert [(r["entity"], r["ids"]) for r in ROWS] == [(r["entity"], r["ids"]) for r in MANIFEST]
SOURCES = {n: ROOT / p for r in MANIFEST for n, p in zip(r["ids"], r["sources"])}
PALETTE = {tuple(bytes.fromhex(c[1:])) for c in json.loads((PACK / "palette.json").read_text())}
ASSETS, COVERAGE = {}, {}
DIRS = ("down", "left", "up", "right")
SUFFIXES = ("center", "edge_n", "edge_e", "edge_s", "edge_w", "outer_ne",
            "outer_nw", "outer_se", "outer_sw", "inner_ne", "inner_nw", "inner_se", "inner_sw")


def load(n):
    return Image.open(SOURCES[n]).convert("RGBA")


def pad(im, size=(16, 16)):
    assert im.width <= size[0] and im.height <= size[1], (im.size, size)
    out = Image.new("RGBA", size)
    out.alpha_composite(im, ((size[0] - im.width) // 2, size[1] - im.height))
    return out


def assemble(size, pieces):
    out = Image.new("RGBA", size)
    for n, x, y in pieces:
        im = load(n)
        assert x >= 0 and y >= 0 and x + im.width <= size[0] and y + im.height <= size[1]
        out.alpha_composite(im, (x, y))
    return out


def strip(frames):
    cell = frames[0].size
    assert all(im.size == cell for im in frames)
    out = Image.new("RGBA", (cell[0] * len(frames), cell[1]))
    for i, im in enumerate(frames):
        out.paste(im, (i * cell[0], 0))
    return out


def save(name, im, ids, processing, entities=(), cell=None):
    colours = {p[:3] for p in im.get_flattened_data() if p[3]}
    assert colours <= PALETTE, (name, colours - PALETTE)
    assert {p[3] for p in im.get_flattened_data()} <= {0, 255}, name
    dest = OUT / (name + ".png")
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest)
    ASSETS[name] = dict(file=dest.relative_to(ROOT).as_posix(), size=list(im.size),
                        cell=list(cell or im.size), ids=list(ids), processing=processing,
                        sources=[SOURCES[n].relative_to(ROOT).as_posix() for n in ids])
    for entity in entities:
        COVERAGE.setdefault(entity, []).append(ASSETS[name]["file"])
    return im


def tile(name, n, entity=None, size=(16, 16)):
    return save(name, pad(load(n), size), [n], "Native pixels; bottom-centre integer padding.",
                [entity] if entity else [])


def bodies():
    for body, walk, hurt in [("player", 477, 486), ("walker", 395, 404),
                             ("runner", 431, 440), ("brute", 413, 422)]:
        folder = "characters" if body == "player" else "zombies"
        for animation, start in [("walk", walk), ("hurt", hurt)]:
            padded = [[pad(load(start + d * 3 + k)) for k in range(3)] for d in range(3)]
            padded.append([im.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for im in padded[1]])
            assert all(im.getchannel("A").getbbox()[3] == 16 for facing in padded for im in facing)
            for d, frames in enumerate(padded):
                source_direction = 1 if d == 3 else d
                ids = list(range(start + source_direction * 3, start + source_direction * 3 + 3))
                note = "Three source-order 16x16 cells; x=(16-w)//2, y=16-h; feet at y15."
                note += " Mirror WHOLE padded left cells." if d == 3 else " Native facing."
                if animation == "walk":
                    note += " Play 0-1-0-2 at 8 fps; idle=cell0, attack=walk at 10 fps + lunge."
                else:
                    note += " Play 0-1-2 at 12 fps; death=down cell0 + blood + runtime fade."
                save(f"{folder}/{body}_{animation}_{DIRS[d]}", strip(frames), ids, note,
                     [body] if body != "player" else [], (16, 16))


def terrain():
    for i, n in enumerate(range(78, 82), 1):
        tile(f"terrain/grass_{i}", n, f"grass_{i}" if i < 4 else "grass extra variant")
    for i, n in enumerate((118, 218), 1):
        tile(f"terrain/flowers_{i}", n, "flower decals")
    for i, n in enumerate((80, 81), 1):
        im = load(n)
        im.putdata([p if p[:3] == (0, 0, 0) else (0, 0, 0, 0) for p in im.get_flattened_data()])
        save(f"terrain/tuft_{i}", im, [n], "Extract black blade clusters without moving pixels.", ["tuft decals"])
    sand = (119, 102, 78, 255)
    base = load(78)
    for name in ("dirt", "dirt_2"):
        im = Image.new("RGBA", (16, 16), sand)
        if name == "dirt_2":
            im.putdata([(127, 118, 93, 255) if p != base.getpixel((0, 0)) else sand for p in base.get_flattened_data()])
        save("terrain/" + name, im, [66, 68, 78], "Pack #77664e fill; dirt_2 retains 78 speckle coordinates in pack #7f765d.",
             [name, "clearing"] if name == "dirt" else [name])
    bands = dict(n=(0, 0, 16, 3), e=(13, 0, 16, 16), s=(0, 13, 16, 16), w=(0, 0, 3, 16))
    boundaries = []
    for suffix in SUFFIXES:
        im = Image.new("RGBA", (16, 16), sand)
        if suffix.startswith(("edge_", "outer_")):
            for side in suffix.split("_")[1]:
                box = bands[side]
                im.paste(base.crop(box), box[:2])
        elif suffix.startswith("inner_"):
            corner = suffix.split("_")[1]
            x, y = (13 if "e" in corner else 0), (0 if "n" in corner else 13)
            im.paste(base.crop((x, y, x + 3, y + 3)), (x, y))
        row = next(r for r in ROWS if r["entity"] == "path_" + suffix)
        boundaries.append(save("terrain/path_" + suffix, im, row["ids"],
                               "Material boundary: pack sand fill + 3px ground bands / 3x3 concave corners.", [row["entity"]]))
    save("terrain/path_boundary", strip(boundaries), [66, 68, 69, 71, 72, 74, 75, 78],
         "13 x 16x16 cells in PathTiles.SUFFIXES order: " + ", ".join(SUFFIXES), cell=(16, 16))
    for row in ROWS:
        if row["entity"].startswith("path topology ") and row["entity"] != "path topology end":
            name = row["entity"][14:]
            tile("terrain/path_native_" + name, row["ids"][0], row["entity"])
    tile("terrain/path_native_isolated", 66)
    for side in "nesw":
        im = load(66)
        box = dict(n=(0, 0, 16, 8), s=(0, 8, 16, 16), e=(8, 0, 16, 16), w=(0, 0, 8, 16))[side]
        im.paste(load(69 if side in "ns" else 68).crop(box), box[:2])
        save("terrain/path_native_end_" + side, im, [66, 68, 69],
             "Round patch plus half straight: connected only to " + side.upper(), ["path topology end"])
    # T-123 owns the live ground/boundary palette; retain source masks and metadata.
    # Native decorative alternatives are unused and deliberately stay pack-original.
    for name, im in terrain_light.recipe().items():
        meta = ASSETS[name]
        save(name, im, meta["ids"], terrain_light.PROCESSING[name], cell=meta["cell"])


def buildings():
    for name in ("command_center", "storage", "workshop", "shelter", "farm", "lumber_yard"):
        row = next(r for r in ROWS if r["entity"] == name)
        ids = row["ids"]
        if name in ("command_center", "storage", "workshop"):
            pieces = [(n, (i % 2) * 16, (0, 7, 23, 39)[i // 2]) for i, n in enumerate(ids[:8])]
            if len(ids) > 8:
                pieces.append((ids[8], 0, 32 if name == "storage" else 40))
        elif name == "farm":
            pieces = [(270, 0, 0), (268, 0, 16), (110, 16, 0), (111, 16, 16)]
        else:
            pieces = [(n, (i % 2) * 16, (0, 7, 23)[i // 2]) for i, n in enumerate(ids[:6])]
            if name == "lumber_yard":
                pieces += [(140, 0, 24), (141, 16, 24)]
        save("buildings/" + name, assemble(tuple(row["cell"]), pieces), ids,
             row["notes"] + " Bottom-centre footprint anchor; no scaling.", [name])
    # Keep Capa 212's complete central upright; rails match its native y2/y7 joins.
    h = Image.new("RGBA", (16, 16)); h.paste(load(208), (0, 6))
    post = Image.new("RGBA", (16, 16)); post.paste(load(212).crop((6, 0, 10, 12)), (6, 4))
    v = Image.new("RGBA", (16, 16)); v.paste(load(211), (9, 0))
    masks = {"post": "", "h": "ew", "v": "ns", "cross": "nesw"}
    masks.update({"end_" + s: s for s in "nesw"})
    masks.update({"corner_" + s: s for s in ("ne", "nw", "se", "sw")})
    masks.update({"tee_" + s: s for s in ("nes", "esw", "nsw", "new")})
    for material in ("fence", "wall_earth"):
        for name, sides in masks.items():
            im = Image.new("RGBA", (16, 16))
            source = load(65) if material == "wall_earth" else h
            for side in sides:
                box = dict(n=(9, 0, 13, 8), s=(9, 8, 13, 16), e=(8, 0, 16, 16), w=(0, 0, 8, 16))[side]
                if material == "wall_earth" and side in "ns":
                    rail = Image.new("RGBA", (16, 16)); rail.paste(load(65).crop((6, 0, 10, 16)), (9, 0))
                else:
                    rail = source if side in "ew" else v
                im.paste(rail.crop(box), box[:2])
            if material == "fence":
                im.alpha_composite(post)
            else:
                im.paste(load(65).crop((6, 0, 10, 16)), (6, 0))
            save(f"buildings/{material}_{name}", im, [65] if material == "wall_earth" else [208, 211, 212],
                 "Cut halves from native EW face/rails and NS rim/upright; connections=" + (sides.upper() or "none") + "; no rotation.",
                 ["reinforced_wall" if material == "wall_earth" else "wooden_wall"])
    for state in ("closed", "open"):
        im = Image.new("RGBA", (16, 16)); im.paste(load(210), (0, 0)); im.paste(load(211), (13, 0))
        if state == "closed":
            im.paste(load(208).crop((3, 0, 13, 8)), (3, 4))
        save("buildings/gate_" + state, im, [208, 210, 211],
             "EW gate, two full-height posts; closed adds removable 10px rail, open posts only.", ["gate"])
    for size in (16, 32):
        im = Image.new("RGBA", (size, size))
        im.paste(load(210), (0, size - 16)); im.paste(load(211), (size - 3, size - 16))
        for x in range(0, size, 16):
            im.paste(load(214), (x, size - 12))
        im.alpha_composite(pad(load(290)), (0, size - 16))
        save(f"buildings/construction_{size // 16}x{size // 16}", im, [210, 211, 214, 290],
             "Optional native scaffold below roof; runtime may tint completed building instead.", [f"construction_{size // 16}x{size // 16}"])


def props_fx():
    for i, crown in ((1, 135), (2, 137)):
        im = Image.new("RGBA", (16, 32)); im.paste(load(crown), (0, 0)); im.paste(pad(load(138)), (0, 16))
        save(f"props/tree_{i}", im, [crown, 138], "Crown y0; trunk bottom-centre in second 16x16 cell; footprint 16x16.", [f"tree_{i}"])
    for i, ids, size in ((1, [289, 290, 193], (16, 16)), (2, [192, 193, 194], (32, 16)), (3, [290, 193, 194], (16, 16))):
        im = pad(load(ids[0]), size)
        for j, n in enumerate(ids[1:]):
            piece = load(n); im.alpha_composite(piece, (size[0] - piece.width if j else 0, size[1] - piece.height))
        save(f"props/scrap_{i}", im, ids, "Bottom-anchored debris/tire composition; no scaling.", [f"scrap_{i}"])
    for entity, prefix, ids, size in (("wrecked cars / tires", "wrecked_car", range(180, 192), (48, 48)),
                                       ("wrecked cars / tires", "tire", (193, 194), (16, 16)),
                                       ("barrels", "barrel", range(147, 151), (16, 16)),
                                       ("signs", "sign", (151, 152, 153, 155, 156, 158, 159, 160), (16, 16)),
                                       ("bushes", "bush", range(82, 92), (16, 16)),
                                       ("straw", "straw", range(119, 125), (16, 16))):
        for i, n in enumerate(ids, 1):
            tile(f"props/{prefix}_{i}", n, entity, size)
    tile("fx/bullet", 373, "bullet / tracer")
    for name, entity, ids in (("pistol_muzzle_flash", "pistol muzzle flash", range(371, 376)),
                               ("shotgun_muzzle_flash", "shotgun muzzle flash", range(365, 371)),
                               ("knife_slash", "knife slash", range(376, 380)),
                               ("blood", "blood impact", range(380, 385)),
                               ("corpse_prone", "corpses with flies", (291, 294, 296)),
                               ("corpse_seated", "corpses with flies", (292, 293, 295)),
                               ("smoke", "smoke", range(322, 328)),
                               ("explosion", "explosion", range(359, 365))):
        save("fx/" + name, strip([pad(load(n)) for n in ids]), ids,
             "Source-order fixed 16x16 bottom-centre cells; separate corpse bodies loop independently.", [entity], (16, 16))
    for i, n in enumerate(range(385, 390), 1):
        tile(f"fx/blood_stain_{i}", n, "blood stains")


def review_artifacts():
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 17)
    cards = []
    for name, meta in ASSETS.items():
        im = Image.open(ROOT / meta["file"])
        big = im.resize((im.width * 4, im.height * 4), Image.Resampling.NEAREST)
        width = 1120 if big.width > 520 else 560
        label = textwrap.wrap(name + ".png", 57 if width == 1120 else 48)
        card = Image.new("RGB", (width, max(112, big.height + 52)), (53, 57, 55))
        card.paste(big, (12, 40), big)
        d = ImageDraw.Draw(card)
        for i, line in enumerate(label):
            d.text((12, i * 18), line, fill="white", font=font)
        cards.append(card)
    reference = Image.new("RGB", (1120, 300), (53, 57, 55)); d = ImageDraw.Draw(reference)
    d.text((12, 0), "Pack ground / Kenney transition references (all x4 NEAREST)", font=font, fill="white")
    for i, im in enumerate((load(78), Image.open(ROOT / "game/assets/tiles/grass_1.png").convert("RGBA"))):
        im = im.resize((im.width * 4, im.height * 4), Image.Resampling.NEAREST)
        reference.paste(im, (12 + i * 180, 32), im)
    cards.append(reference)
    rows = []; pending = None
    for card in cards:
        if card.width == 1120:
            if pending is not None: rows.append(pending); pending = None
            rows.append(card)
        elif pending is None:
            pending = Image.new("RGB", (1120, card.height), (53, 57, 55)); pending.paste(card, (0, 0))
        else:
            row = Image.new("RGB", (1120, max(pending.height, card.height)), (53, 57, 55))
            row.paste(pending, (0, 0)); row.paste(card, (560, 0)); rows.append(row); pending = None
    if pending is not None: rows.append(pending)
    sheet = Image.new("RGB", (1120, sum(r.height for r in rows))); y = 0
    pages = RUN / "contact_pages"; pages.mkdir(exist_ok=True, parents=True)
    for i, row in enumerate(rows):
        sheet.paste(row, (0, y)); y += row.height
    sheet.save(RUN / "contact_sheet.png")
    for i in range(0, len(rows), 8):
        batch = rows[i:i + 8]; page = Image.new("RGB", (1120, sum(r.height for r in batch))); y = 0
        for row in batch: page.paste(row, (0, y)); y += row.height
        page.save(pages / f"page_{i // 8 + 1:02d}.png")
    for body in ("player", "walker", "runner", "brute"):
        folder = "characters" if body == "player" else "zombies"; frames = []
        for k in (0, 1, 0, 2):
            frame = Image.new("RGB", (400, 120), (53, 57, 55)); d = ImageDraw.Draw(frame)
            for i, direction in enumerate(DIRS):
                im = Image.open(OUT / f"{folder}/{body}_walk_{direction}.png").crop((k * 16, 0, k * 16 + 16, 16))
                im = im.resize((64, 64), Image.Resampling.NEAREST); frame.paste(im, (i * 100 + 16, 30), im)
                d.text((i * 100 + 16, 6), direction, font=font, fill="white")
                d.line((i * 100 + 16, 94, i * 100 + 79, 94), fill=(212, 204, 171))
            frames.append(frame)
        frames[0].save(RUN / f"walk_check_{body}.gif", save_all=True, append_images=frames[1:], duration=125, loop=0, disposal=2)


def documents():
    path = ROOT / "game/assets/ASSET_INDEX.md"
    marker = "\n## T-102 processed Ittai Manero pixel assets\n"
    original, _, tail = path.read_bytes().decode("utf-8").partition(marker.strip())
    next_section = tail.find("\n## ")
    later_sections = tail[next_section:].strip() if next_section != -1 else ""
    newline = "\r\n" if "\r\n" in original else "\n"
    lines = [marker, "Native pixels, Nearest project default, lossless imports, no mipmaps. Rebuild with `python asset_library/ittaimanero/tools/process_pack.py`.",
             "", "| File | Purpose | Pack source Capa numbers | Processing |", "| --- | --- | --- | --- |"]
    for name, meta in sorted(ASSETS.items()):
        lines.append(f"| `pixel/{name}.png` | {name.split('/')[-1].replace('_', ' ')} | {', '.join(map(str, meta['ids']))} | {meta['processing']} |")
    section = original.rstrip() + "\n" + "\n".join(lines) + "\n\n" + later_sections + "\n"
    path.write_bytes(section.replace("\r\n", "\n").replace("\n", newline).encode("utf-8"))
    path = ROOT / "CREDITS.md"; original = path.read_bytes().decode("utf-8")
    marker = "\n## T-102 pixel pack art\n"
    credit = "Ittai Manero, Zombie Apocalypse Tileset (itch.io): free for commercial use, no redistribution of the raw pack; only processed sprites used by the game are included."
    newline = "\r\n" if "\r\n" in original else "\n"
    before, _, tail = original.partition(marker.strip())
    next_section = tail.find("\n## ")
    later_sections = tail[next_section:].strip() if next_section != -1 else ""
    section = before.rstrip() + marker + "\n" + credit + "\n\n" + later_sections + "\n"
    path.write_bytes(section.replace("\r\n", "\n").replace("\n", newline).encode("utf-8"))


def coverage_report():
    skips = []
    for row in ROWS:
        name = row["entity"]
        if name in COVERAGE: continue
        if row["gap"]:
            reason = "GAP: T-108 UI/font work." if name.startswith(("HUD ", "UI ")) else "GAP: T-118 gap-fill."
            if name == "guard_post": reason = "GAP: guard post art explicitly outside M6 scope."
        elif name.startswith("asphalt road"): reason = "Optional unused asphalt vocabulary; T-103 uses mapped dirt boundary/native paths."
        elif name == "Turret Zombie (spare)": reason = "Curated unused spare; T-106 only spawns walker/runner/brute."
        elif name in ("blueprint / placement ghost", "damaged building look"):
            COVERAGE[name] = COVERAGE["command_center"]; continue
        elif name in ("rescue helicopter shadow", "HP bars / progress indicators", "selection / placement outlines", "floating text / phase banners / screen tint"):
            reason = "Explicitly procedural runtime rendering; helicopter shadow depends on T-118 body alpha."
        elif name.startswith(("UI ", "HUD ")) or name == "inventory slots": reason = "UI kit belongs to T-108, outside T-103 through T-107 swaps."
        elif name in ("title scene", "application icon"): reason = "Live menu composition / export icon belong to later menu and release tasks."
        else: raise AssertionError("Uncovered mapped row: " + name)
        skips.append(dict(entity=name, reason=reason))
    result = dict(png_count=len(ASSETS), palette_pass=True, alpha_binary=True, coverage=COVERAGE,
                  skipped_rows=skips, assets=list(ASSETS.values()))
    (RUN / "asset_validation.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"PASS: {len(ASSETS)} PNGs; all visible RGBs in {len(PALETTE)}-colour pack palette; alpha 0/255; mapping coverage recorded.")


def check_imports():
    assert "textures/canvas_textures/default_texture_filter=0" in (ROOT / "game/project.godot").read_text()
    for name, meta in ASSETS.items():
        path = ROOT / (meta["file"] + ".import"); text = path.read_text()
        assert "compress/mode=0" in text and "mipmaps/generate=false" in text, path
        assert 'importer="texture"' in text and "process/size_limit=0" in text, path
    assert not list((ROOT / "game").rglob("*Capa-*.png"))
    result = json.loads((RUN / "asset_validation.json").read_text(encoding="utf-8"))
    result["imports"] = dict(count=len(ASSETS), lossless=True, mipmaps=False, project_filter="Nearest")
    (RUN / "asset_validation.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"PASS: {len(ASSETS)} lossless native PNG imports, no mipmaps, project Nearest default; no Capa PNG names in game.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check-imports", action="store_true")
    args = parser.parse_args(); RUN.mkdir(exist_ok=True, parents=True)
    bodies(); terrain(); buildings(); props_fx(); coverage_report(); documents(); review_artifacts()
    if args.check_imports: check_imports()
