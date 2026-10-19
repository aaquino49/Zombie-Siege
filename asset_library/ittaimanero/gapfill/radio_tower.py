"""Recombined hut, fence footings and radio with a pixel-placed tapered lattice."""
from common import ImageDraw, canvas, colour, load, remap, save


def build():
    im = canvas((32, 48)); d = ImageDraw.Draw(im)
    black = colour("000000"); metal = colour("878c96"); light = colour("b6aeae")
    # Footing/front is at the very bottom, within the bottom 32x32 footprint.
    d.rectangle((1, 44, 30, 47), fill=black)
    d.rectangle((2, 44, 29, 45), fill=colour("58534a"))
    d.rectangle((18, 35, 30, 44), fill=black)
    d.rectangle((19, 36, 29, 43), fill=colour("b6aeae"))
    # Native small-building roof material, front face below it.
    roof = load(94).crop((0, 0, 14, 7))
    im.alpha_composite(roof, (17, 29))
    d.line((18, 35, 30, 35), fill=black)
    d.line((19, 36, 19, 42), fill=colour("f6cadc"))
    radio = load(356).crop((0, 9, 10, 19))
    im.alpha_composite(radio, (20, 35))
    # Fence post pieces provide the two vertical base legs and their contour.
    post = remap(load(210), {"504433": "878c96", "726650": "b6aeae"})
    im.alpha_composite(post, (3, 28)); im.alpha_composite(post, (15, 28))
    for a, b in [((9, 7), (3, 43)), ((11, 7), (17, 43))]:
        d.line((*a, *b), fill=black, width=3)
        d.line((*a, *b), fill=metal)
    for y, lx, rx in [(14, 8, 12), (22, 6, 14), (31, 5, 15), (40, 3, 17)]:
        d.line((lx, y, rx, y), fill=black, width=3)
        d.line((lx, y-1, rx, y-1), fill=light)
    for a, b in [((8, 15), (14, 21)), ((14, 23), (5, 30)), ((5, 32), (17, 39))]:
        d.line((*a, *b), fill=black, width=3)
        d.line((*a, *b), fill=colour("58534a"))
    # Outlined aerial boom and fixed mast.
    d.line((10, 1, 10, 10), fill=black, width=3)
    d.line((10, 2, 10, 8), fill=light)
    d.rectangle((4, 4, 16, 7), fill=black)
    d.line((5, 5, 15, 5), fill=metal)
    d.point((4, 3), fill=black); d.point((16, 3), fill=black)
    save("buildings/radio_tower", im, [356, 210, 211, 94, 104],
         "gap-fill: edited/recombined small-building roof/front, recoloured fence footings and radio equipment; "
         "hand-placed tapered lattice and antenna. 104/211 are companion material references. "
         "Bottom 32x32 footprint, overhang above.", footprint=[32, 32], anchor=[16, 48])


if __name__ == "__main__":
    build()
