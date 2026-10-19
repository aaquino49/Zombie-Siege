"""Elevated open wooden guard deck from fence rails/posts; darker underside band."""
from common import ImageDraw, canvas, colour, load, save


def build():
    im = canvas((16, 32)); d = ImageDraw.Draw(im)
    black = colour("000000"); wood = colour("726650"); shadow = colour("504433")
    # Repeated native posts retain their vertical, black-edged pack vocabulary.
    for x in (1, 12):
        im.alpha_composite(load(210 if x == 1 else 211), (x, 16))
    for a, b in [((3, 18), (12, 29)), ((12, 18), (3, 29))]:
        d.line((*a, *b), fill=black, width=3)
        d.line((*a, *b), fill=shadow)
    # Top/deck/front in 3/4 view; dark band separates raised deck from legs.
    d.rectangle((1, 10, 14, 17), fill=black)
    d.rectangle((2, 10, 13, 13), fill=wood)
    for x in (4, 7, 10):
        d.line((x, 10, x, 13), fill=shadow)
    d.rectangle((2, 14, 13, 15), fill=colour("4e4637"))
    d.line((2, 16, 13, 16), fill=colour("211818"))
    # Fence rail slices on the far and near deck edges; preserve original pixels.
    im.alpha_composite(load(214).crop((2, 0, 14, 3)), (2, 4))
    im.alpha_composite(load(214).crop((2, 4, 14, 7)), (2, 8))
    im.alpha_composite(load(207).crop((0, 0, 4, 12)), (0, 3))
    im.alpha_composite(load(209).crop((12, 0, 16, 12)), (12, 3))
    d.line((1, 31, 4, 31), fill=black); d.line((11, 31, 14, 31), fill=black)
    save("buildings/watchtower", im, [207, 209, 210, 211, 214],
         "gap-fill: edited/recombined fence posts and rail slices; hand-placed deck top/front, "
         "dark underside band and cross braces. Elevated open guard platform; bottom 16x16 footprint.",
         footprint=[16, 16], anchor=[8, 32])


if __name__ == "__main__":
    build()
