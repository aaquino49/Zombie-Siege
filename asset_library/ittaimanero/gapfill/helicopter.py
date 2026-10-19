"""3/4 rescue craft, car cabin material, fixed-hub discrete horizontal rotor phases."""
from common import ImageDraw, canvas, colour, load, mirror, save, strip


def build():
    im = canvas((48, 32)); d = ImageDraw.Draw(im)
    black = colour("000000"); front = colour("726650"); roof = colour("b6aeae")
    # Helicopter points left on the upper-right fly-in. Roof and front side are visible.
    d.polygon([(3, 17), (7, 12), (13, 10), (26, 10), (30, 13), (34, 15),
               (43, 12), (44, 7), (47, 7), (47, 14), (44, 18), (34, 20),
               (29, 25), (13, 25), (6, 22), (3, 20)], fill=black)
    d.polygon([(5, 17), (9, 13), (14, 11), (26, 11), (30, 15), (33, 16),
               (44, 13), (45, 8), (46, 8), (46, 13), (43, 16), (33, 19),
               (29, 21), (12, 21), (6, 19)], fill=roof)
    d.polygon([(5, 18), (13, 19), (29, 20), (32, 19), (28, 24), (14, 24), (7, 21)], fill=front)
    # Reuse native car cabin pixels (including window pillar and weathered side).
    cabin = load(167).crop((10, 3, 22, 13))
    im.alpha_composite(cabin, (14, 12))
    # Edited angular cockpit and side-door windows; no new colours.
    d.polygon([(6, 16), (10, 13), (13, 13), (13, 18), (6, 18)], fill=black)
    d.line((8, 15, 12, 15), fill=colour("d4ccab"))
    d.line((7, 17, 12, 17), fill=colour("928969"))
    d.rectangle((17, 19, 21, 23), fill=black)
    d.rectangle((18, 20, 20, 22), fill=colour("878c96"))
    d.rectangle((22, 20, 26, 23), fill=black)
    d.rectangle((23, 21, 25, 22), fill=colour("878c96"))
    d.line((13, 12, 13, 18), fill=colour("d4ccab"))
    d.line((35, 18, 44, 16), fill=colour("58534a"))
    # Skids and two supports below the fuselage are explicitly in the front plane.
    d.line((12, 25, 15, 28), fill=black, width=2)
    d.line((27, 25, 29, 28), fill=black, width=2)
    d.rectangle((9, 28, 31, 29), fill=black)
    d.line((10, 28, 30, 28), fill=colour("b6aeae"))
    # Two-pixel symmetric mast straddles the x=24 cell-centre mirror axis.
    d.rectangle((23, 14, 24, 17), fill=black)
    d.line((23, 15, 24, 15), fill=colour("b6aeae"))
    save("fx/helicopter_body_left", im, [167, 171, 221],
         "gap-fill: edited car 167 cabin; hand-placed fuselage top/front, cockpit, tail and skids; "
         "171 and fan 221 are material references. Left-facing fly-in.", hub=[24, 16])
    save("fx/helicopter_body_right", mirror(im), [167, 171, 221],
         "gap-fill: edited: exact whole-cell mirror of left; symmetric central mast.", hub=[24, 16])
    frames = []
    # Each phase is authored on the flattened horizontal plane. No rotated bitmap.
    endpoints = [((3, 24), (44, 24), (24, 13), (23, 35)),
                 ((6, 14), (42, 34), (16, 33), (31, 15)),
                 ((6, 34), (42, 14), (15, 15), (32, 33))]
    for a, b, c, e in endpoints:
        frame = canvas((48, 48)); draw = ImageDraw.Draw(frame)
        draw.line((*a, *b), fill=black, width=3)
        draw.line((*c, *e), fill=black, width=3)
        draw.line((*a, 24, 24), fill=colour("58534a"))
        draw.rectangle((22, 22, 25, 25), fill=black)
        draw.rectangle((23, 23, 24, 24), fill=colour("b6aeae"))
        frames.append(frame)
    save("fx/helicopter_rotor", strip(frames), [223, 224, 225],
         "gap-fill: hand-placed edited fan vocabulary in horizontal 3/4 plane; three discrete "
         "blade phases with constant central hub; no rotation/blur.", (48, 48), hub=[24, 24])


if __name__ == "__main__":
    build()
