"""Road-detail pedestal and edited weapon mount, four discrete facings, pivot (8,8)."""
from common import ImageDraw, canvas, colour, load, mirror, remap, save


def build():
    base = remap(load(55), {"211818": None, "726650": "878c96", "504433": "58534a",
                           "4e4637": "58534a", "77664e": "878c96"})
    d = ImageDraw.Draw(base)
    d.rectangle((5, 7, 10, 10), fill=colour("000000"))
    d.rectangle((6, 8, 9, 9), fill=colour("b6aeae"))
    save("buildings/turret_base", base, [55],
         "gap-fill: edited/recoloured round road detail into metal pedestal, black front rim.", pivot=[8, 8])
    # Preserve the pistol barrel contour, combining a shotgun barrel fragment.
    left = canvas((16, 16))
    pistol = remap(load(335), {"ffffff": "b6aeae", "b6aeae": "878c96", "866752": "58534a"})
    shotgun = remap(load(332), {"ffffff": "b6aeae", "b6aeae": "878c96", "866752": "58534a"})
    left.alpha_composite(shotgun.crop((0, 0, 8, 3)), (1, 5))
    left.alpha_composite(pistol, (1, 6))
    d = ImageDraw.Draw(left)
    d.rectangle((6, 7, 10, 10), fill=colour("000000"))
    d.rectangle((7, 8, 9, 9), fill=colour("878c96"))
    facings = {"left": left, "right": mirror(left)}
    for direction in ("down", "up"):
        im = canvas((16, 16)); d = ImageDraw.Draw(im)
        d.rectangle((5, 7, 10, 10), fill=colour("000000"))
        d.rectangle((6, 8, 9, 9), fill=colour("878c96"))
        if direction == "up":
            d.rectangle((7, 1, 9, 8), fill=colour("000000"))
            d.line((8, 2, 8, 8), fill=colour("b6aeae"))
        else:
            d.rectangle((7, 8, 9, 14), fill=colour("000000"))
            d.line((8, 9, 8, 12), fill=colour("b6aeae"))
            d.point((8, 13), fill=colour("58534a"))
        facings[direction] = im
    for direction in ("down", "left", "up", "right"):
        save(f"buildings/turret_barrel_{direction}", facings[direction], [335, 332],
             "gap-fill: edited/recoloured pistol and shotgun barrel, hand-placed axial facings; "
             "four discrete directions, shared mount pivot; no rotation.", pivot=[8, 8])


if __name__ == "__main__":
    build()
