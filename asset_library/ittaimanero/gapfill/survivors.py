"""Seven semantic recolours of T-102 player strips; no frame movement or hurt tint."""
from common import DIRS, ROOT, cells, colour, curated, mirror, save, strip
import json

# Shirt, interior hair, human skin. Keep zombie olive colours out of skin masks.
LOOKS = {
    "blue": ("878c96", "000000", "a77967"),
    "brown": ("866752", "000000", "9c7761"),
    "green": ("949974", "d4ccab", "a77967"),
    "old": ("b6aeae", "878c96", "ad644b"),
    "survivor": ("c36448", "443830", "a77967"),
    "hitman": ("211818", "878c96", "ad644b"),
    "soldier": ("928969", "443830", "866752"),
}


def recolour(frame, direction, look):
    out = frame.copy()
    shirt, hair, skin = [colour(c) for c in look]
    top = frame.getchannel("A").getbbox()[1]
    for y in range(16):
        for x in range(16):
            p = frame.getpixel((x, y))
            # Source white occurs only on cloth, never eyes. Trousers are b6aeae.
            if p == colour("ffffff"):
                out.putpixel((x, y), shirt)
            elif p == colour("a77967"):
                out.putpixel((x, y), skin)
            elif p == colour("000000") and top < y <= top + (3 if direction == "up" else 2):
                # Recolour enclosed hair pixels; preserve silhouette and facial eyes.
                if 0 < x < 15 and all(frame.getpixel((nx, ny))[3] for nx, ny in
                                      ((x-1, y), (x+1, y), (x, y-1), (x, y+1))):
                    out.putpixel((x, y), hair)
    return out


def build():
    variants = json.loads((ROOT / "game/data/balance.json").read_text())["survivor_variants"]
    assert variants == list(LOOKS), variants
    for variant, look in LOOKS.items():
        left = None
        for d, direction in enumerate(DIRS):
            original = curated(f"characters/player_walk_{direction}")
            if direction == "right":
                frames = [mirror(f) for f in left]
            else:
                frames = [recolour(f, direction, look) for f in cells(original)]
                if direction == "left":
                    left = frames
            offset = (1 if d == 3 else d) * 3
            save(f"characters/survivor_{variant}_walk_{direction}", strip(frames),
                 list(range(477 + offset, 480 + offset)),
                 f"gap-fill: recoloured semantic shirt/skin/interior hair masks {look}; "
                 "preserved eyes, black contour, trousers and exact T-102 padding. "
                 "0-1-0-2 at 8 fps; idle=0. Right mirrors complete padded left cells.", (16, 16))
            save(f"characters/survivor_{variant}_hurt_{direction}",
                 curated(f"characters/player_hurt_{direction}"),
                 list(range(486 + offset, 489 + offset)),
                 "gap-fill: edited naming only; exact authored red/black/white hurt cells, no tint. "
                 "0-1-2 at 12 fps. Same bottom-centre 16x16 cells.", (16, 16))


if __name__ == "__main__":
    build()
