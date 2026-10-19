"""Two angular outlined stones, editing debris material into solid top/front facets."""
from common import ImageDraw, canvas, colour, load, remap, save


def build():
    for variant in ("a", "b"):
        im = canvas((16, 16)); d = ImageDraw.Draw(im)
        # A grey debris fragment under the solid facets retains a chipped projection.
        debris = remap(load(290), {"504433": "58534a", "726650": "878c96"})
        im.alpha_composite(debris.crop((3, 3, 10, 10)), (4, 7))
        if variant == "a":
            contour = [(2, 8), (4, 4), (10, 3), (14, 7), (14, 12), (11, 14), (4, 14), (1, 11)]
            top = [(3, 8), (5, 5), (10, 4), (13, 7), (12, 10), (7, 11), (3, 10)]
            front = [(3, 11), (7, 12), (12, 10), (12, 12), (10, 13), (4, 13)]
        else:
            contour = [(1, 10), (4, 7), (6, 3), (10, 4), (13, 7), (15, 10), (13, 13), (5, 14), (2, 12)]
            top = [(3, 10), (6, 7), (7, 4), (10, 5), (12, 8), (14, 10), (9, 11), (6, 10)]
            front = [(3, 11), (8, 12), (13, 11), (12, 12), (6, 13), (3, 12)]
        d.polygon(contour, fill=colour("000000"))
        d.polygon(top, fill=colour("878c96"))
        d.polygon(front, fill=colour("58534a"))
        d.line((5, 7, 8, 5), fill=colour("b6aeae"))
        d.point((7, 10), fill=colour("000000"))
        d.line((10, 8, 9, 10), fill=colour("58534a"))
        save(f"props/rock_{variant}", im, [290, 65],
             "gap-fill: edited/recoloured debris fragment; hand-placed solid grey stone top/front "
             "facets and pack black contour. Terrain wall 65 is a material/outline reference.")


if __name__ == "__main__":
    build()
