"""T-224 missing semantic UI glyphs, hand-placed in the pack palette."""
from m12_common import *

def build():
    icons={}
    def put(name,im,purpose):
        save('ui/'+name,im,[],purpose+'; hand-placed pack-palette pixels, one-pixel black contours; style reference icon_survivors.png.')
        save('ui/x2/'+name,im.resize((32,32),Image.Resampling.NEAREST),[], 'Exact 2x nearest copy of ui/'+name+'.png.')
        icons[name]=im
    for mood,fill in [('inspired','#949974'),('steady','#b2acac'),('low','#8e886a'),('breaking','#c36448')]:
        im=blank((16,16)); d=ImageDraw.Draw(im)
        d.polygon([(5,2),(10,2),(13,5),(13,10),(10,13),(5,13),(2,10),(2,5)],fill=color('#000000'))
        d.polygon([(5,3),(10,3),(12,5),(12,10),(10,12),(5,12),(3,10),(3,5)],fill=color(fill))
        d.line((5,3,9,3),fill=color('#d4ccab'))
        if mood=='inspired':
            d.line((4,6,5,5),fill=color('#000000')); d.line((9,5,10,6),fill=color('#000000'))
            d.line([(4,8),(5,10),(6,11),(9,11),(10,10),(11,8)],fill=color('#000000'))
            d.line((6,9,9,9),fill=color('#ffffff'))
        elif mood=='steady':
            d.point((5,6),fill=color('#000000'));d.point((10,6),fill=color('#000000'))
            d.line((5,10,10,10),fill=color('#000000'))
        elif mood=='low':
            d.line((4,7,5,7),fill=color('#000000'));d.line((9,7,10,7),fill=color('#000000'))
            d.line([(5,11),(5,10),(6,9),(9,9),(10,10),(10,11)],fill=color('#000000'))
        else:
            d.line([(8,3),(7,4),(8,5),(7,6)],fill=color('#000000'))
            d.line((4,6,6,7),fill=color('#000000'));d.line((9,7,11,6),fill=color('#000000'))
            d.rectangle((5,9,6,10),fill=color('#000000'))
            d.rectangle((9,8,10,10),fill=color('#d4ccab'));d.point((9,11),fill=color('#ffffff'))
        put('icon_mood_'+mood,im,mood.title()+' mood badge')
    im=blank((16,16));d=ImageDraw.Draw(im)
    d.rectangle((6,1,10,3),fill=color('#000000'));d.line((7,2,9,2),fill=color('#d4ccab'))
    d.rectangle((7,3,9,6),fill=color('#000000'))
    d.polygon([(7,6),(3,11),(3,13),(4,14),(12,14),(13,13),(13,11),(9,6)],fill=color('#000000'))
    d.polygon([(8,5),(8,7),(4,12),(4,13),(12,13),(12,12),(8,7)],fill=color('#d4ccab'))
    d.rectangle((5,11,11,12),fill=color('#949974'));d.point((6,9),fill=color('#ffffff'))
    put('icon_research',im,'Research points: wide-bottom laboratory flask')
    im=blank((16,16));d=ImageDraw.Draw(im)
    d.polygon([(7,1),(13,4),(12,10),(10,13),(7,15),(4,13),(2,10),(1,4)],fill=color('#000000'))
    d.polygon([(7,2),(12,5),(11,10),(9,12),(7,13),(5,12),(3,10),(2,5)],fill=color('#b2acac'))
    d.line((7,3,7,12),fill=color('#d4ccab'));d.line((4,6,10,6),fill=color('#d4ccab'))
    d.line((3,9,5,11),fill=color('#878c96'))
    put('icon_tech_defense',im,'Defense branch: pointed metal shield')
    im=blank((16,16));d=ImageDraw.Draw(im)
    d.rectangle((7,5,10,14),fill=color('#000000'));d.rectangle((8,6,9,13),fill=color('#a77967'))
    d.polygon([(2,2),(10,2),(13,4),(13,6),(10,7),(2,7),(1,6),(1,3)],fill=color('#000000'))
    d.rectangle((3,3,9,5),fill=color('#b2acac'));d.line((3,3,9,3),fill=color('#d4ccab'))
    d.line((10,4,12,4),fill=color('#878c96'));d.point((8,12),fill=color('#d4ccab'))
    put('icon_tech_economy',im,'Economy branch: broad horizontal hammer and wood handle')
    im=blank((16,16));d=ImageDraw.Draw(im)
    for x,y,shirt in [(8,2,'#949974'),(2,5,'#d4ccab')]:
        d.rectangle((x+1,y,x+4,y+5),fill=color('#000000'))
        d.rectangle((x+2,y+1,x+3,y+3),fill=color('#a77967'))
        d.polygon([(x,y+5),(x+5,y+5),(x+6,y+7),(x+6,y+9),(x-1,y+9),(x-1,y+7)],fill=color('#000000'))
        d.rectangle((x,y+6,x+5,y+8),fill=color(shirt))
    put('icon_tech_survivors',im,'Survivors branch: paired staggered heads and shoulders')
    return icons

if __name__ == '__main__': build()
