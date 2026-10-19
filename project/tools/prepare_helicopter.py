"""T-083: trim, pivot-align and Lanczos-downscale generated helicopter sources.

Run from any directory. Pillow is the only dependency. Sources remain untouched.
"""
from pathlib import Path
import json
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ORIGINALS = ROOT / "asset_library/generated/originals"
ASSETS = ROOT / "game/assets"
RUN = ROOT / "project/runs/T-083/a1"
LANCZOS = Image.Resampling.LANCZOS


def prepare(name, pivot, size, opacity=1.0):
    source = Image.open(ORIGINALS / f"t083_helicopter_{name}.png").convert("RGBA")
    # Ignore nearly invisible generation specks when trimming; retain original alpha.
    bounds = source.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
    left, top, right, bottom = bounds
    px, py = pivot
    rx = max(px - left, right - px) + 12
    ry = max(py - top, bottom - py) + 12
    # A symmetric crop places the actual mechanical hub at the canvas centre.
    trimmed = source.crop((px - rx, py - ry, px + rx, py + ry))
    scale = min((size[0] - 4) / trimmed.width, (size[1] - 4) / trimmed.height)
    scaled_size = tuple(max(2, round(d * scale / 2) * 2) for d in trimmed.size)
    sprite = trimmed.resize(scaled_size, LANCZOS)
    if opacity != 1.0:
        # Multiply, rather than replace, alpha to retain the generated trailing blur.
        sprite.putalpha(sprite.getchannel("A").point(lambda a: round(a * opacity)))
    canvas = Image.new("RGBA", size)
    canvas.alpha_composite(sprite, ((size[0] - sprite.width) // 2, (size[1] - sprite.height) // 2))
    path = ASSETS / f"fx/helicopter_{name}.png"
    canvas.save(path)
    return canvas, {
        "original": f"asset_library/generated/originals/t083_helicopter_{name}.png",
        "original_size": list(source.size), "source_hub": list(pivot),
        "visible_source_bounds_alpha_gt_16": list(bounds),
        "symmetric_crop": [px - rx, py - ry, px + rx, py + ry],
        "resized_size": list(scaled_size), "canvas": list(size),
        "final_hub": [size[0] / 2, size[1] / 2], "alpha_multiplier": opacity,
        "output": str(path.relative_to(ROOT)).replace("\\", "/"),
    }


def place(canvas, sprite, centre):
    canvas.alpha_composite(sprite, (round(centre[0] - sprite.width / 2), round(centre[1] - sprite.height / 2)))


def checker(size):
    panel = Image.new("RGBA", size, "#e1e6e5")
    draw = ImageDraw.Draw(panel)
    for x in range(0, size[0], 16):
        for y in range(0, size[1], 16):
            if (x // 16 + y // 16) % 2:
                draw.rectangle((x, y, x + 15, y + 15), fill="#cbd3d2")
    return panel


def contact_sheet(body, rotor):
    sheet = Image.new("RGBA", (1100, 730), "#202b30")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
    small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 15)
    draw.text((24, 16), "T-083 | Rescue helicopter | transparent sprites, east facing", font=font, fill="white")
    composite = Image.new("RGBA", (224, 224))
    place(composite, body, (112, 112))
    place(composite, rotor.rotate(-20, Image.Resampling.BICUBIC, expand=True), (112, 112))
    for x, sprite, title in [(24, body, "Body 176 x 96 | hub (88, 48)"),
                              (386, rotor, "Rotor 192 x 192 | hub (96, 96)"),
                              (748, composite, "Composite | rotor +20 degrees")]:
        panel = checker((328, 240))
        place(panel, sprite, (164, 120))
        sheet.alpha_composite(panel, (x, 58))
        draw.text((x, 309), title, font=small, fill="white")
    draw.text((24, 345), "Native 1x on Kenney grass | CC 128px | helicopter body 176px (1.375x) | no sprite scaling", font=font, fill="white")
    field = Image.new("RGBA", (1056, 288))
    grass = Image.open(ASSETS / "tiles/grass_1.png").convert("RGBA")
    for x in range(0, field.width, 64):
        for y in range(0, field.height, 64):
            field.alpha_composite(grass, (x, y))
    for name, centre in [("buildings/radio_tower.png", (120, 130)),
                          ("buildings/command_center.png", (300, 130)),
                          ("props/tree_1.png", (700, 130)),
                          ("buildings/turret_base.png", (830, 130)),
                          ("characters/survivor_blue_stand.png", (960, 130))]:
        place(field, Image.open(ASSETS / name).convert("RGBA"), centre)
    place(field, composite, (500, 130))
    sheet.alpha_composite(field, (24, 380))
    for x, title in [(90, "Radio tower"), (280, "CC"), (475, "Helicopter"),
                      (680, "Tree"), (805, "Turret"), (930, "Survivor")]:
        draw.text((x, 682), title, font=small, fill="white")
    destination = ROOT / "asset_library/generated/helicopter_contact.png"
    sheet.convert("RGB").save(destination)
    RUN.mkdir(parents=True, exist_ok=True)
    shutil.copy2(destination, RUN / "contact_sheet.png")


def main():
    body, body_meta = prepare("body", (922, 472), (176, 96))
    rotor, rotor_meta = prepare("rotor", (627, 627), (192, 192), 0.65)
    contact_sheet(body, rotor)
    manifest = {
        "task": "T-083", "source": "OpenAI built-in image_gen, generated by Codex",
        "body_candidates": 3, "rotor_candidates": 2,
        "selection": "Third body simplifies the silhouette; first rotor retains the cleanest blur. Original alpha is preserved, multiplied by 0.65 for the final rotor.",
        "assets": [body_meta, rotor_meta],
        "prompt_template": "Top-down (90 degrees overhead) game sprite of a {thing}, flat clean vector style matching Kenney.nl top-down asset packs, simple soft shading, transparent background, centered, no text, no perspective.",
        "body_prompt": "Edit this transparent overhead helicopter BODY sprite. Keep the clean simple silhouette, RIGHT facing nose, olive fuselage, grey skids, dark blue windshield, short tail on the LEFT, and NO MAIN ROTOR BLADES. Crucial fix: reposition the small circular grey main rotor mounting hub LEFTWARD to the exact MIDPOINT between left tail tip and right nose tip, still on the longitudinal horizontal symmetry axis. The hub must sit at the midpoint of the whole silhouette, not midpoint of just the cabin. Flatten colors to simple solid Kenney.nl color blocks, no gradients or textured highlights. The image must remain fully transparent outside the helicopter, with no ground shadows. Preserve true 90-degree overhead camera. Single sprite only.",
        "rotor_prompt": "Use case: stylized-concept. Asset type: main rotor ONLY, transparent 2D overhead game sprite. Top-down (90 degrees overhead) game sprite of a helicopter main rotor alone, flat clean vector style matching Kenney.nl top-down asset packs, simple soft shading, transparent background, centered, no text, no perspective. Exactly four slender blades in a rotationally symmetric plus shape radiating from a small round grey hub at EXACT canvas centre. Equal blade lengths and identical blade shapes at 90-degree intervals. Muted desaturated grey metal, broad flat shapes, very clean silhouette, subtle soft semi-transparent motion blur trailing each blade to suggest spinning; blades alpha roughly 0.6, hub can be opaque. No helicopter body, no landing skids, no background, no shadow or directional lighting, no text. Fully visible square rotor silhouette with transparent outer margins, intended for 192x192px square final canvas. Blades and blur must look natural when this square sprite is rotated to any angle. No opaque blur disk, keep plenty of transparent space between the blades. Single sprite only.",
    }
    (ORIGINALS / "t083_helicopter_sources.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest["assets"], indent=2))


if __name__ == "__main__":
    main()
