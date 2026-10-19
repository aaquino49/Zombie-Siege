"""T-224 Field Lab: native small-building modules and palette-only edits."""
from m12_common import *

def build():
    im = blank((32, 32))
    # Shelter's exact 32-wide shell/ground contact; reserve four roof pixels
    # for a small receiving dish, compress only the featureless wall rows.
    for n, x, y, crop in [(94,0,4,None),(104,16,4,None),
                         (93,0,11,(0,4,16,16)),(105,16,11,(0,4,16,16)),
                         (92,0,23,None),(98,16,23,None)]:
        part = load(n)
        if crop: part = part.crop(crop)
        part = remap(part, {'#b6aeae':'#949974', '#f6cadc':'#d4ccab',
                            '#a77967':'#7f765d', '#9a7868':'#726650'})
        im.paste(part, (x,y), part)
    d = ImageDraw.Draw(im)
    # Broad lit front window: desk, separate paper sheet and flask inside.
    d.rectangle((4,12,18,26), fill=color('#000000'))
    d.rectangle((5,13,17,23), fill=color('#d4ccab'))
    d.line((5,13,17,13), fill=color('#ffffff'))
    d.rectangle((6,24,17,25), fill=color('#77664e'))
    d.line((7,26,7,28), fill=color('#000000'))
    d.line((16,26,16,28), fill=color('#000000'))
    d.rectangle((13,19,16,22), fill=color('#ffffff'))
    d.line((14,20,16,20), fill=color('#878c96'))
    d.line((14,22,15,22), fill=color('#878c96'))
    d.line((8,16,10,16), fill=color('#000000'))
    d.rectangle((9,17,9,19), fill=color('#000000'))
    d.polygon([(9,19),(6,22),(6,23),(11,23),(11,22)], fill=color('#000000'))
    d.line((7,22,10,22), fill=color('#949974'))
    # Door remains right, with a cream handle; no ammo, crates or tall mast.
    d.point((23,27), fill=color('#d4ccab'))
    # Small bowl, two-pixel support and diagonal feed at the roof's right.
    d.polygon([(21,0),(28,0),(28,2),(26,4),(23,4),(21,2)], fill=color('#000000'))
    d.line((22,1,27,1), fill=color('#b2acac'))
    d.line((23,2,26,2), fill=color('#d4ccab'))
    d.line((24,3,25,3), fill=color('#878c96'))
    d.line((25,4,25,8), fill=color('#000000'))
    d.line((24,7,26,7), fill=color('#878c96'))
    d.line((24,0,26,2), fill=color('#000000'))
    return save('buildings/field_lab', im, [94,104,93,105,92,98],
                'Small-building shell; crop four plain wall rows for dish clearance; olive plaster remap; hand-pixel lit desk/window, papers, flask and compact dish. Native 32x32, bottom anchor y31.')

if __name__ == '__main__': build()
