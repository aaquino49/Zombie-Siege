"""T-224 campfire base and cyclic four-frame flame; no scaling/rotation."""
from m12_common import *

def build():
    base = blank((16,16)); d = ImageDraw.Draw(base)
    # Six stepped stones, with grey-swapped Terrain wall texture fragments.
    texture = remap(load(65), {'#47352c':'#58534a', '#77664e':'#878c96'})
    for x,y in [(3,9),(9,9),(1,11),(12,11),(3,13),(9,13)]:
        d.rectangle((x,y,x+3,y+2), fill=color('#000000'))
        base.paste(texture.crop((1,0,3,1)), (x+1,y))
        d.line((x+1,y+1,x+2,y+1), fill=color('#878c96'))
        d.point((x+2,y+2), fill=color('#58534a'))
    # Crop the pack cut log to six-by-four; mirror its cut end for the other log.
    log = load(140).crop((0,1,6,5))
    base.paste(log,(4,10),log)
    log = log.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    base.paste(log,(7,11),log)
    d.line((5,11,9,11),fill=color('#47352c'))
    save('buildings/campfire',base,[65,140],
         'Terrain-wall stone texture remapped to pack greys; cropped mirrored native cut logs, hand-edited ring; unlit 16x16 blueprint/build-bar base.')
    donor = remap(load(360), {'#f6cadc':'#e0451b', '#ffffff':'#d4ccab'}).crop((4,3,12,12))
    puff = remap(load(327).crop((0,0,3,2)), {'#d4ccab':'#878c96'})
    shapes = [ [(7,5),(8,7),(10,6),(10,9),(11,10),(10,12),(5,12),(4,10),(6,8)],
               [(7,4),(8,7),(9,6),(10,8),(10,10),(11,11),(9,12),(5,12),(4,10),(6,8)],
               [(8,5),(9,8),(11,7),(10,10),(11,11),(9,12),(5,12),(4,10),(6,9),(6,7)],
               [(7,6),(8,8),(9,7),(10,9),(10,11),(9,12),(5,12),(4,10),(6,8)] ]
    frames=[]
    for k,points in enumerate(shapes):
        im=base.copy(); layer=blank((16,16)); ld=ImageDraw.Draw(layer)
        ld.polygon(points,fill=color('#9d2c0f'))
        # Recoloured explosion material clipped by the newly edited flame mask.
        for y in range(5,12):
            for x in range(5,11):
                if layer.getpixel((x,y))[3]:
                    p=donor.getpixel((x-4,y-3))
                    if p[3]: layer.putpixel((x,y),p)
        ld.line((7,9,7,11),fill=color('#d4ccab'))
        ld.point((8,11),fill=color('#ffffff'))
        im.alpha_composite(layer)
        im.paste(puff,[(7,0),(8,0),(8,1),(7,1)][k],puff)
        frames.append(im)
    strip=blank((64,16))
    for k,im in enumerate(frames):strip.paste(im,(k*16,0))
    save('buildings/campfire_lit',strip,[65,140,360,327],
         'Fixed base; clipped/recoloured explosion pixels in four edited flame masks; small cropped smoke puff travels a closed 2x2 cycle. Frames medium/tall/medium/short, 0-1-2-3 repeat; suggested 8 FPS.')
    return base,frames

if __name__ == '__main__': build()
