"""Build T-224 assets, visual handoff and mechanical acceptance evidence.

Usage: python asset_library/ittaimanero/gapfill/m12_batch.py [run-directory]
"""
import sys
sys.dont_write_bytecode = True
import json
from PIL import Image, ImageDraw, ImageOps, ImageFont
import m12_common as c
import field_lab
import campfire
import m12_ui

RUN = c.ROOT/'project/runs/T-224/a1' if len(sys.argv)==1 else c.Path(sys.argv[1])
RUN.mkdir(parents=True,exist_ok=True)
existing = {str(p.relative_to(c.ROOT)):c.hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (c.OUT).rglob('*.png')
            if p.stem not in {'field_lab','campfire','campfire_lit','icon_research',
                             'icon_tech_defense','icon_tech_economy','icon_tech_survivors',
                             'icon_mood_inspired','icon_mood_steady','icon_mood_low','icon_mood_breaking'}}
lab=field_lab.build()
base,frames=campfire.build()
icons=m12_ui.build()
for p,digest in existing.items():
    assert c.hashlib.sha256((c.ROOT/p).read_bytes()).hexdigest()==digest, p

sheet=Image.new('RGB',(1120,1150),'#302b2b');d=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',15)
small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',12)
def label(x,y,text):d.text((x,y),text,font=font,fill='#d4ccab')
def paste(im,x,y,scale=1):
    im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
    sheet.paste(im,(x,y),im)

label(20,14,'T-224 / M12: native pack-palette sprites, Nearest integer scales')
label(20,44,'New buildings: native 1x and inspection 4x; each flame frame is 16x16')
paste(lab,30,78);paste(lab,94,68,4);label(30,208,'Field Lab 32x32')
paste(base,292,84);paste(base,329,84,4);label(278,208,'Campfire base')
for k,im in enumerate(frames):
    x=466+k*153;paste(im,x,84);paste(im,x+30,78,4);label(x,164,f'frame {k}')
label(20,241,'Day: bottom anchors aligned; lab/campfire beside current building sprites (4x)')
ground=Image.open(c.OUT/'terrain/grass_1.png').convert('RGBA')
names=['field_lab','campfire_lit','shelter','storage','command_center','workshop']
buildings=[lab,frames[0]]+[Image.open(c.OUT/f'buildings/{n}.png').convert('RGBA') for n in names[2:]]
for row,tint in enumerate([(1,1,1),(.55,.60,.80)]):
    y=273+row*262
    scene=Image.new('RGBA',(272,51))
    for gy in range(0,51,16):
        for gx in range(0,272,16):scene.paste(ground,(gx,gy))
    for k,im in enumerate(buildings):scene.alpha_composite(im,(k*44+4,49-im.height))
    scene.putdata([tuple(round(p[i]*tint[i]) for i in range(3))+(p[3],) for p in scene.get_flattened_data()])
    paste(scene,16,y,4)
    for k,n in enumerate(['Field Lab','Campfire','Shelter','Storage','Command Center','Workshop']):
        d.text((32+k*176,y+202),n,font=small,fill='#d4ccab')
    if row==0:label(20,y+224,'Night: exact DayNightTint.NIGHT_COLOR multiplication (0.55, 0.60, 0.80)')
label(20,780,'UI: every new icon 1x and exact 2x on panel.png (panel tiles repeated, never filtered)')
panel=Image.open(c.OUT/'ui/panel.png').convert('RGBA')
for k,(name,im) in enumerate(icons.items()):
    x=20+k*136
    paste(panel,x,811);paste(im,x+8,814)
    paste(panel,x+39,805,2);paste(im,x+55,811,2)
    d.text((x,857),name.replace('icon_','').replace('tech_','').replace('mood_',''),font=small,fill='#d4ccab')
label(20,892,'Mood expressions in greyscale at 1x and 2x; color is not required to distinguish them')
for k,(name,im) in enumerate(list(icons.items())[:4]):
    x=40+k*240
    grey=ImageOps.grayscale(im).convert('RGBA');grey.putalpha(im.getchannel('A'))
    pg=ImageOps.grayscale(panel).convert('RGBA');pg.putalpha(panel.getchannel('A'))
    paste(pg,x,925);paste(grey,x+8,928)
    paste(pg,x+50,919,2);paste(grey,x+66,925,2)
    paste(grey,x+138,917,4)
    label(x,986,name.replace('icon_mood_',''))
label(20,1028,'Existing palette / outline references at 2x: survivors, food, scrap, ammo')
for k,n in enumerate(['icon_survivors','icon_food','icon_scrap','icon_ammo']):
    im=Image.open(c.OUT/f'ui/{n}.png').convert('RGBA')
    paste(panel,30+k*170,1058,2);paste(im,46+k*170,1064,2)
    d.text((30+k*170,1108),n,font=small,fill='#d4ccab')
sheet.save(RUN/'contact_sheet.png')
# Review-only animation: Nearest, stationary footing, 8 FPS, infinite loop.
previews=[]
for im in frames:
    bg=Image.new('RGBA',(16,16),'#949974');bg.alpha_composite(im)
    previews.append(bg.resize((128,128),Image.Resampling.NEAREST).convert('RGB'))
previews[0].save(RUN/'campfire_loop.gif',save_all=True,append_images=previews[1:],duration=125,loop=0,disposal=2)
changes=[sum(a!=b for a,b in zip(frames[k].get_flattened_data(),frames[(k+1)%4].get_flattened_data())) for k in range(4)]
assert max(changes)<=32, changes
assert len({im.tobytes() for im in frames})==4
assert all(im.crop((0,13,16,16)).tobytes()==base.crop((0,13,16,16)).tobytes() for im in frames)
for name,im in icons.items():
    assert Image.open(c.OUT/f'ui/x2/{name}.png').tobytes()==im.resize((32,32),Image.Resampling.NEAREST).tobytes()
report={'assets':list(c.ASSETS.values()),'palette_colors':len(c.PALETTE),'alpha':[0,255],
        'existing_pngs_unchanged':len(existing),'campfire_adjacent_changed_pixels_including_wrap':changes,
        'four_unique_frames':True,'base_bottom_three_rows_fixed':True,'exact_2x_copies':8,
        'night_tint':[.55,.60,.80]}
(RUN/'asset_validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(c.PACK/'gapfill/m12_manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f'PASS: {len(c.ASSETS)} PNGs; all palette/binary-alpha; eight exact 2x copies; {len(existing)} existing PNGs unchanged; cyclic frame deltas {changes}')
print(RUN/'contact_sheet.png')
