"""Rebuild T-118 PNGs, provenance, 4x review sheets and walk GIF. Add --check-imports after Godot import."""
import argparse
import hashlib
import json
from PIL import ImageFont

from common import ASSETS, DIRS, OUT, PACK, PALETTE, ROOT, RUN, Image, ImageDraw, canvas, cells, curated, load, mirror
import survivors
import turret
import radio_tower
import watchtower
import rocks
import helicopter


def validate(check_imports):
    expected = {}
    for variant in survivors.LOOKS:
        for direction in DIRS:
            for animation in ("walk", "hurt"):
                expected[f"characters/survivor_{variant}_{animation}_{direction}"] = (48, 16)
    for direction in DIRS:
        expected[f"buildings/turret_barrel_{direction}"] = (16, 16)
    expected.update({"buildings/turret_base": (16, 16), "buildings/radio_tower": (32, 48),
                     "buildings/watchtower": (16, 32), "props/rock_a": (16, 16), "props/rock_b": (16, 16),
                     "fx/helicopter_body_left": (48, 32), "fx/helicopter_body_right": (48, 32),
                     "fx/helicopter_rotor": (144, 48)})
    assert set(expected) == set(ASSETS) and len(ASSETS) == 68
    for name, size in expected.items():
        im = curated(name)
        assert im.size == size, name
        assert {p[:3] for p in im.get_flattened_data() if p[3]} <= PALETTE, name
        assert {p[3] for p in im.get_flattened_data()} <= {0, 255}, name
    for direction in DIRS:
        identities = set()
        original = curated(f"characters/player_walk_{direction}")
        for variant in survivors.LOOKS:
            walk = curated(f"characters/survivor_{variant}_walk_{direction}")
            identities.add(walk.tobytes())
            assert walk.getchannel("A").tobytes() == original.getchannel("A").tobytes()
            for f in cells(walk):
                assert f.getchannel("A").getbbox()[3] == 16
            hurt = curated(f"characters/survivor_{variant}_hurt_{direction}")
            assert hurt.tobytes() == curated(f"characters/player_hurt_{direction}").tobytes()
            if direction == "right":
                left = curated(f"characters/survivor_{variant}_walk_left")
                assert all(a.tobytes() == mirror(b).tobytes() for a, b in zip(cells(walk), cells(left)))
        assert len(identities) == 7
        assert original.tobytes() not in identities
        for zombie in ("walker", "runner", "brute"):
            assert curated(f"zombies/{zombie}_walk_{direction}").tobytes() not in identities
    assert curated("fx/helicopter_body_right").tobytes() == mirror(curated("fx/helicopter_body_left")).tobytes()
    rotors = cells(curated("fx/helicopter_rotor"), (48, 48))
    assert len({f.tobytes() for f in rotors}) == 3
    assert all(f.crop((22, 22, 26, 26)).tobytes() == rotors[0].crop((22, 22, 26, 26)).tobytes() for f in rotors)
    result = dict(png_count=68, palette_pass=True, palette_colours=len(PALETTE), alpha_binary=True,
                  survivor_unique_per_facing=True, survivor_alpha_matches_player=True, feet_baseline=16,
                  hurt_exact=True, right_mirrors_padded_left=True, helicopter_mirror=True,
                  rotor_hub_constant=True, assets=list(ASSETS.values()))
    if check_imports:
        assert "textures/canvas_textures/default_texture_filter=1" in (ROOT / "game/project.godot").read_text()
        for meta in ASSETS.values():
            text = (ROOT / (meta["file"] + ".import")).read_text()
            assert 'importer="texture"' in text and "compress/mode=0" in text
            assert "mipmaps/generate=false" in text and "process/size_limit=0" in text
        result["imports"] = dict(count=68, lossless=True, mipmaps=False, project_filter="Nearest")
    (RUN / "asset_validation.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("PASS: 68 assets, palette, dimensions, alpha, preserved silhouettes/hurt, mirrors, distinct survivors, fixed rotor hub"
          + ("; lossless/Nearest imports" if check_imports else ""))


def section(path, title, content):
    text = path.read_bytes().decode("utf-8")
    marker = "\n## " + title
    if marker in text:
        before, after = text.split(marker, 1)
        following = after.find("\n## ")
        text = before + (after[following:] if following >= 0 else "")
    path.write_bytes((text.rstrip() + marker + "\n\n" + content.rstrip() + "\n").encode("utf-8"))


def documents():
    (PACK / "gapfill/manifest.json").write_text(json.dumps(list(ASSETS.values()), indent=2) + "\n", encoding="utf-8")
    lines = ["Native 16px Ittai Manero gap-fill art; all visible colours are from the 41-colour pack palette, "
             "binary alpha, lossless PNG and project Nearest. Rebuild with `python asset_library/ittaimanero/gapfill/build_all.py`. "
             "Each asset family also has its own runnable script in that folder. No generated imagery is used. "
             "Exact sources, sizes, footprints, hubs and PNG hashes are recorded in `gapfill/manifest.json`. "
             "Art is staged for later graphics swaps; this task changes no game code.", "",
             "Walk/hurt strips contain three 16x16 cells. Walk sequence is 0-1-0-2 at 8fps; hurt is 0-1-2 at 12fps. "
             "Survivors preserve player alpha/padding and authored hurt frames. Turret pivot (8,8); radio/watchtower "
             "bottom anchors (16,48)/(8,32); helicopter body/rotor hubs (24,16)/(24,24).", "",
             "| File | Purpose | Pack source file(s) | Processing |", "|---|---|---|---|"]
    for meta in ASSETS.values():
        file = meta["file"].removeprefix("game/assets/")
        purpose = file.rsplit("/", 1)[-1].removesuffix(".png").replace("_", " ")
        sources = "<br>".join("`" + s.removeprefix("asset_library/ittaimanero/sprites/") + "`" for s in meta["sources"])
        lines.append(f"| `{file}` | {purpose} | {sources} | {meta['processing']} |")
    section(ROOT / "game/assets/ASSET_INDEX.md", "T-118 palette-only pixel gap-fill", "\n".join(lines))
    section(ROOT / "CREDITS.md", "T-118 pixel gap-fill adaptations",
            "Ittai Manero, Zombie Apocalypse Tileset (itch.io), under the pack's existing free-commercial-use terms. "
            "Codex edited/recombined and recoloured the processed player, road detail, weapon, fence, small-building, "
            "debris and car pieces, then hand-placed missing pixels in the pack palette for survivor identities, "
            "turret, towers, rocks and rescue helicopter. Per-file donors and material references are listed in "
            "`game/assets/ASSET_INDEX.md` and `asset_library/ittaimanero/gapfill/manifest.json`. No AI-generated imagery "
            "ships in these pixel assets; the raw pack stays outside the game export.")


BG = (61, 59, 55)
try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
except OSError:
    FONT = ImageFont.load_default(size=18)


def put(sheet, im, xy, ground=False):
    # Every sprite pixel is enlarged exactly 4x Nearest, including pack comparisons.
    x, y = xy
    if ground:
        tile = curated("terrain/grass_1").resize((64, 64), Image.Resampling.NEAREST)
        for tx in range(0, im.width * 4, 64):
            for ty in range(0, im.height * 4, 64):
                sheet.paste(tile, (x + tx, y + ty))
    large = im.resize((im.width * 4, im.height * 4), Image.Resampling.NEAREST)
    sheet.paste(large, xy, large)


def label(sheet, xy, text):
    ImageDraw.Draw(sheet).text(xy, text, fill="white", font=FONT)


def characters(animation):
    sheet = Image.new("RGB", (1540, 880), BG)
    label(sheet, (16, 14), f"T-118 {animation} / 4x NEAREST / fixed 16x16 cells / pack palette")
    label(sheet, (16, 38), "Each row: down, left, up, right strips. Pack context: player / walker / runner / brute.")
    for row, variant in enumerate(survivors.LOOKS):
        y = 84 + row * 110
        label(sheet, (16, y + 24), variant)
        for k, direction in enumerate(DIRS):
            x = 150 + k * 230
            put(sheet, curated(f"characters/survivor_{variant}_{animation}_{direction}"), (x, y))
            label(sheet, (x, y + 72), direction)
        for k, name in enumerate(("player", "walker", "runner", "brute")):
            folder = "characters" if name == "player" else "zombies"
            x = 1090 + k * 105
            put(sheet, cells(curated(f"{folder}/{name}_{animation}_down"))[0], (x, y))
            label(sheet, (x, y + 72), name)
    return sheet


def prop_sheet():
    sheet = Image.new("RGB", (1540, 1420), BG)
    label(sheet, (16, 12), "Turret layers and assembled facings / shared pivot (8,8) / adjacent pack architecture")
    base = curated("buildings/turret_base")
    put(sheet, base, (24, 150)); label(sheet, (24, 224), "base")
    for k, direction in enumerate(DIRS):
        x = 125 + k * 130; barrel = curated(f"buildings/turret_barrel_{direction}")
        put(sheet, barrel, (x, 65)); label(sheet, (x, 133), direction + " layer")
        built = base.copy(); built.alpha_composite(barrel)
        put(sheet, built, (x, 150), True); label(sheet, (x, 224), direction + " built")
    for name, x, y in [("buildings/command_center", 780, 42), ("buildings/fence_h", 970, 170)]:
        put(sheet, curated(name), (x, y)); label(sheet, (x, 240), name.rsplit("/", 1)[1])
    for n, x in [(55, 1100), (335, 1240), (332, 1380)]:
        put(sheet, load(n), (x, 75)); label(sheet, (x, 155), f"pack {n}")
    label(sheet, (16, 285), "Tall buildings / footprint at bottom / raised wooden deck with dark underside")
    for name, x, y in [("buildings/radio_tower", 32, 320), ("buildings/watchtower", 230, 384),
                       ("buildings/command_center", 440, 320), ("buildings/shelter", 655, 352),
                       ("buildings/fence_h", 855, 448)]:
        put(sheet, curated(name), (x, y)); label(sheet, (x, 522), name.rsplit("/", 1)[1])
    for n, x, y in [(210, 1040, 448), (356, 1170, 416), (214, 1320, 448)]:
        put(sheet, load(n), (x, y)); label(sheet, (x, 522), f"pack {n}")
    label(sheet, (16, 580), "Grey angular boulders / adjacent pack trees / debris and terrain-wall material references")
    for name, x, y in [("props/rock_a", 32, 680), ("props/rock_b", 180, 680),
                       ("props/tree_1", 380, 616), ("props/tree_2", 540, 616)]:
        put(sheet, curated(name), (x, y), True); label(sheet, (x, 755), name.rsplit("/", 1)[1])
    for n, x in [(290, 750), (65, 935)]:
        put(sheet, load(n), (x, 680)); label(sheet, (x, 755), f"pack {n}")
    label(sheet, (16, 825), "Rescue helicopter / body hubs (24,16), rotor hubs (24,24) / car and fan pack context")
    for name, x in [("fx/helicopter_body_left", 32), ("fx/helicopter_body_right", 295)]:
        put(sheet, curated(name), (x, 930)); label(sheet, (x, 1070), name.rsplit("/", 1)[1])
    rotor = cells(curated("fx/helicopter_rotor"), (48, 48))
    for k, frame in enumerate(rotor):
        put(sheet, frame, (560 + k * 240, 894)); label(sheet, (560 + k * 240, 1100), f"rotor phase {k}")
    put(sheet, load(167), (1300, 940)); label(sheet, (1300, 1070), "pack car 167")
    composite = canvas((48, 48)); composite.alpha_composite(curated("fx/helicopter_body_left"), (0, 8))
    composite.alpha_composite(rotor[0])
    put(sheet, composite, (32, 1150)); label(sheet, (32, 1360), "body + rotor / coincident hubs")
    put(sheet, curated("buildings/command_center"), (345, 1145))
    label(sheet, (345, 1360), "pack command center")
    for n, x in [(223, 590), (224, 750), (225, 910), (171, 1130)]:
        put(sheet, load(n), (x, 1220)); label(sheet, (x, 1360), f"pack {n}")
    return sheet


def review_artifacts():
    walk = characters("walk"); hurt = characters("hurt"); props = prop_sheet()
    walk.save(RUN / "contact_survivors.png"); hurt.save(RUN / "contact_hurt.png")
    props.save(RUN / "contact_props.png")
    master = Image.new("RGB", (1540, walk.height + hurt.height + props.height), BG)
    master.paste(walk, (0, 0)); master.paste(hurt, (0, walk.height))
    master.paste(props, (0, walk.height + hurt.height)); master.save(RUN / "contact_sheet.png")
    frames = []
    for direction in DIRS:
        for phase in (0, 1, 0, 2):
            frame = Image.new("RGB", (1000, 155), BG)
            label(frame, (16, 8), f"All seven survivors / {direction} / 8fps / authored torso bob, fixed feet cells")
            for k, variant in enumerate(survivors.LOOKS):
                x = 35 + k * 135
                label(frame, (x, 36), variant)
                body = cells(curated(f"characters/survivor_{variant}_walk_{direction}"))[phase]
                put(frame, body, (x, 62), True)
            label(frame, (16, 138), "0-1-0-2; every frame stays on the same 16x16 cell, no trimming or recentering")
            frames.append(frame)
    frames[0].save(RUN / "survivor_walk.gif", save_all=True, append_images=frames[1:],
                   duration=[120, 130] * 8, loop=0, disposal=2, optimize=False)
    # Static filmstrip of exactly the GIF's down-facing frames for visual inspection.
    film = Image.new("RGB", (1000, 620), BG)
    for k in range(4):
        film.paste(frames[k], (0, k * 155))
    film.save(RUN / "walk_alignment.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-imports", action="store_true")
    args = parser.parse_args()
    RUN.mkdir(parents=True, exist_ok=True)
    for module in (survivors, turret, radio_tower, watchtower, rocks, helicopter):
        module.build()
    validate(args.check_imports); documents(); review_artifacts()
