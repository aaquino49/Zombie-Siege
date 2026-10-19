"""Rebuild T-101 mapping, 4x NEAREST comparison sheet, palette and alignment proof.

Run from repository root: python asset_library/ittaimanero/tools/build_mapping.py
Requires Pillow; optional psd-tools documents why the offset fallback was used.
Writes only project/ and asset_library/, never game/.
"""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import json
import shutil
import textwrap
from PIL import Image, ImageDraw, ImageFont
from mapping_data import ROWS

ROOT = Path(__file__).resolve().parents[3]
PACK = ROOT / "asset_library/ittaimanero"
RUN = ROOT / "project/runs/T-101/a1"
RUN.mkdir(parents=True, exist_ok=True)
FONT = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 20)
SMALL = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 17)
FILES = {int(p.stem.split("Capa-")[1]): p for p in (PACK / "sprites").rglob("*Capa-*.png")}
INVENTORY = PACK / "sprites/Inventory interface"
INVENTORY_FILES = [INVENTORY / (n + ".png") for n in
                   ["EMPTY_SLOT", "USING_SLOT", "GUN_SLOT", "SINGLE_AMMO_SLOT", "RADIO_SLOT"]]


def load(n):
    return Image.open(FILES[n]).convert("RGBA")


def pad(im, size):
    assert im.width <= size[0] and im.height <= size[1], (im.size, size)
    out = Image.new("RGBA", size)
    out.alpha_composite(im, ((size[0] - im.width) // 2, size[1] - im.height))
    return out


def assembled(size, pieces):
    out = Image.new("RGBA", size)
    for n, x, y in pieces:
        out.alpha_composite(load(n), (x, y))
    return out


def shell(kind):
    if kind in ["cc", "storage", "workshop"]:
        pieces = [(1,0,0),(25,16,0),(2,0,7),(26,16,7),
                  (19 if kind == "workshop" else 3,0,23),(27,16,23),
                  (5,0,39),(24 if kind == "storage" else 15,16,39)]
        if kind == "storage": pieces.append((119,0,32))
        if kind == "workshop": pieces.append((193,0,40))
        return assembled((32,48), pieces)
    if kind == "farm":
        return assembled((32,32),[(270,0,0),(268,0,16),(110,16,0),(111,16,16)])
    pieces = [(94,0,0),(104,16,0),(93,0,7),(105,16,7),(92,0,23),
              (103 if kind == "lumber" else 98,16,23)]
    if kind == "lumber": pieces += [(140,0,24),(141,16,24)]
    return assembled((32,32),pieces)


def path_tile(suffix):
    # Material masks extend to occupied neighbour sides. Existing PathTiles has
    # a boundary atlas, whereas the pack has narrow connected tracks.
    out = load(78).copy()
    sand = load(66).getpixel((8,8))
    d = ImageDraw.Draw(out)
    d.rectangle((0,0,15,15), fill=sand)
    base = load(78)
    if suffix.startswith("edge_"):
        side = suffix[-1]
        box = {"n":(0,0,16,3),"s":(0,13,16,16),"w":(0,0,3,16),"e":(13,0,16,16)}[side]
        out.paste(base.crop(box),box[:2])
    elif suffix.startswith("outer_"):
        corner = suffix.split("_")[1]
        for side in corner:
            box = {"n":(0,0,16,3),"s":(0,13,16,16),"w":(0,0,3,16),"e":(13,0,16,16)}[side]
            out.paste(base.crop(box),box[:2])
    elif suffix.startswith("inner_"):
        corner=suffix.split("_")[1]
        x=13 if "e" in corner else 0; y=0 if "n" in corner else 13
        out.paste(base.crop((x,y,x+3,y+3)),(x,y))
    return out


SHIRTS = {"blue":(135,140,150),"brown":(134,103,82),"green":(148,153,116),
          "old":(182,174,174),"survivor":(195,100,72),"hitman":(33,24,24),"soldier":(146,137,105)}


def previews(r):
    kind = r.get("preview") or ""
    if kind in ["cc","shelter","farm","storage","workshop","lumber"]:
        return [(shell(kind), "assembled proposal")]
    if kind == "tree": return [(assembled((16,32),[(r["ids"][0],0,0),(138,0,16)]),"crown + trunk")]
    if kind == "dirt": return [(path_tile("center"),"derived sand fill")]
    if kind.startswith("path_"): return [(path_tile(kind[5:]),"derived boundary mask")]
    if kind.startswith("actor_") or kind.startswith("survivor_"):
        start = int(kind[6:]) if kind.startswith("actor_") else 477
        stride = 4 if start == 449 else 3
        frames = []
        for direction, n, flip in [("down",start,False),("left",start+stride,False),
                                    ("up",start+2*stride,False),("right",start+stride,True)]:
            im=pad(load(n),(16,16))
            if kind.startswith("survivor_"):
                # Review swatches only; retain semantic mask refinement as GAP.
                variant=kind[9:]; colour=SHIRTS[variant]
                pixels=im.load()
                for y in range(16):
                    for x in range(16):
                        if pixels[x,y] == (255,255,255,255): pixels[x,y]=colour+(255,)
                if variant == "old":
                    for y in range(5):
                        for x in range(16):
                            if pixels[x,y] == (0,0,0,255) and 3 < x < 12: pixels[x,y]=(182,174,174,255)
            if flip: im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            frames.append((im,direction + (" mirrored" if flip else "")))
        return frames
    if kind in ["ui_panel","ui_hover","ui_pressed","inventory"]:
        fs = INVENTORY_FILES if kind == "inventory" else INVENTORY_FILES[:1]
        result=[]
        for f in fs:
            im=Image.open(f).convert("RGBA")
            if kind == "ui_hover": im.alpha_composite(Image.open(INVENTORY_FILES[1]).convert("RGBA"))
            if kind == "ui_pressed":
                im=im.copy(); px=im.load()
                for y in range(im.height):
                    for x in range(im.width):
                        if px[x,y][:3] == (33,24,24): px[x,y]=(0,0,0,255)
            result.append((im,f.stem))
        return result
    if kind in ["bar_bg","bar_fill","outline"]:
        im=Image.new("RGBA",(32,6) if kind.startswith("bar") else (16,16))
        d=ImageDraw.Draw(im); d.rectangle((0,0,im.width-1,im.height-1),outline=(89,82,72,255),width=1)
        if kind == "bar_fill": d.rectangle((1,1,im.width-2,im.height-2),fill=(182,70,44,255))
        return [(im,"palette primitive proposal")]
    if kind == "scaffold":
        size=tuple(r["cell"]); im=Image.new("RGBA",size)
        for x in [0,size[0]-3]: im.alpha_composite(load(210),(x,size[1]-16))
        im.alpha_composite(load(214),(0,size[1]-8)); im.alpha_composite(load(290),(0,size[1]-13))
        return [(im,"scaffold recombination")]
    if kind == "title":
        im=Image.new("RGBA",(64,48)); base=load(78)
        for y in range(0,48,16):
            for x in range(0,64,16): im.alpha_composite(base,(x,y))
        im.alpha_composite(shell("cc"),(16,0)); im.alpha_composite(pad(load(395),(16,16)),(0,32))
        im.alpha_composite(pad(load(477),(16,16)),(48,32))
        return [(im,"scene vocabulary only")]
    if kind == "icon":
        im=assembled((32,32),[(1,0,0),(25,16,0),(3,0,7),(27,16,7),(5,0,23),(15,16,23)])
        im.alpha_composite(load(356),(10,0))
        return [(im,"CC/radio motif study")]
    # Native sources, not falsely labelled finished gap assets.
    return [(load(n),f"Capa-{n}") for n in r["ids"]]


def gallery(items, width=1080):
    scaled=[]
    for im,label in items:
        scaled.append((im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST),label))
    x=y=0; line_h=0; positions=[]
    for im,label in scaled:
        w=max(im.width, SMALL.getlength(label)+8)
        if x+w>width and x: y+=line_h+16; x=0; line_h=0
        assert w <= width, (label,w,width)
        positions.append((im,label,int(x),y)); x+=int(w)+24; line_h=max(line_h,im.height+28)
    h=y+line_h+12
    out=Image.new("RGB",(width,max(h,72)),(57,60,61)); d=ImageDraw.Draw(out)
    for im,label,x,y in positions:
        out.paste(im,(x,y),im); d.text((x,y+im.height+4),label,font=SMALL,fill=(225,220,201))
    if not positions: d.text((8,20),"NONE - no current sprite",font=FONT,fill="white")
    return out


def card(r):
    old=[]
    for p in r["old"]:
        im=Image.open(ROOT/"game/assets"/p).convert("RGBA")
        if p == "ui/title_art.png":
            im=im.resize((160,90),Image.Resampling.NEAREST); label="title overview thumbnail (160x90)"
        else: label=Path(p).stem
        old.append((im,label))
    a=gallery(old); b=gallery(previews(r)); h=max(a.height,b.height)+142
    out=Image.new("RGB",(2280,h),(30,34,38)); d=ImageDraw.Draw(out)
    d.text((20,12),r["entity"] + ("  [GAP - source references / recolour study only]" if r["gap"] else ""),font=FONT,fill=(255,217,115))
    d.text((20,42),"CURRENT: native PNG x4 NEAREST",font=SMALL,fill="white")
    d.text((1160,42),"PROPOSED: native pack/cell x4 NEAREST",font=SMALL,fill="white")
    out.paste(a,(20,74)); out.paste(b,(1160,74))
    for j,line in enumerate(textwrap.wrap(r["notes"],width=185)[:2]):
        d.text((20,h-49+j*20),line,font=SMALL,fill=(210,211,216))
    return out


def main():
    sources=[]
    for r in ROWS:
        for n in r["ids"]: assert n in FILES, n
        r["sources"]=[FILES[n].relative_to(ROOT).as_posix() for n in r["ids"]]
        if (r.get("preview") or "").startswith("ui_") or r.get("preview") == "inventory":
            r["sources"] += [p.relative_to(ROOT).as_posix() for p in INVENTORY_FILES]
        for p in r["old"]: assert (ROOT/"game/assets"/p).is_file(),p
        sources.extend(r["sources"])
    existing={p.relative_to(ROOT/"game/assets").as_posix() for p in (ROOT/"game/assets").rglob("*.png")}
    covered={p for r in ROWS for p in r["old"]}
    assert existing <= covered, "Unmapped current PNGs: " + str(existing-covered)
    (PACK/"mapping_manifest.json").write_text(json.dumps(ROWS,indent=2),encoding="utf-8")
    colours=set()
    for f in (PACK/"sprites").rglob("*.png"):
        colours.update(px[:3] for px in Image.open(f).convert("RGBA").get_flattened_data() if px[3]==255)
    colours=sorted(colours); pal=Image.new("RGB",(len(colours),1)); pal.putdata(colours); pal.save(PACK/"palette.png")
    (PACK/"palette.json").write_text(json.dumps(["#%02x%02x%02x"%c for c in colours],indent=2))
    cards=[card(r) for r in ROWS]
    sheet=Image.new("RGB",(2280,sum(c.height for c in cards)),(30,34,38)); y=0
    for c in cards: sheet.paste(c,(0,y)); y+=c.height
    sheet.save(PACK/"mapping_contact_sheet.png")
    shutil.copy2(PACK/"mapping_contact_sheet.png",RUN/"contact_sheet.png")
    pages=RUN/"contact_pages"; pages.mkdir(exist_ok=True)
    for i in range(0,len(cards),4):
        batch=cards[i:i+4]; page=Image.new("RGB",(2280,sum(c.height for c in batch)))
        y=0
        for c in batch: page.paste(c,(0,y)); y+=c.height
        page.save(pages/f"page_{i//4+1:02d}.png")
    alignment=Image.new("RGB",(1100,4*3*122),(52,56,59)); d=ImageDraw.Draw(alignment)
    sequences=[]; index=0
    for name,start in [("player",477),("walker",395),("runner",431),("brute",413)]:
        for facing,base in [("down",start),("left",start+3),("up",start+6)]:
            frames=[]
            for slot,k in enumerate([0,1,0,2]):
                im=pad(load(base+k),(16,16)); frames.append(im)
                big=im.resize((64,64),Image.Resampling.NEAREST); x=220+slot*190; y=index*122+20
                alignment.paste(big,(x,y),big); d.rectangle((x,y,x+63,y+63),outline=(130,130,130)); d.line((x,y+64,x+63,y+64),fill=(255,215,90))
                d.text((x,y+72),f"{base+k}: {load(base+k).size}",font=SMALL,fill="white")
            d.text((5,index*122+30),name+" "+facing,font=FONT,fill="white"); index+=1; sequences.append(frames)
    alignment.save(RUN/"frame_alignment.png")
    gif_frames=[]
    for k in range(4):
        canvas=Image.new("RGB",(12*80,96),(57,60,61))
        for j,seq in enumerate(sequences):
            im=seq[k].resize((64,64),Image.Resampling.NEAREST); canvas.paste(im,(j*80+8,8),im)
        gif_frames.append(canvas)
    gif_frames[0].save(RUN/"walk_alignment.gif",save_all=True,append_images=gif_frames[1:],duration=125,loop=0)
    report=dict(entities=len(ROWS),current_pngs=len(existing),all_current_pngs_covered=True,
                source_paths_checked=len(set(sources)),palette_colours=len(colours),sheet_size=sheet.size,
                gap_entities=[r["entity"] for r in ROWS if r["gap"]])
    (RUN/"mapping_validation.json").write_text(json.dumps(report,indent=2))
    table=["| Entity | Current file (under game/assets/) | Exact pack folder + file(s) | Frames x directions | Native size / padded cell | Notes | GAP? |",
           "|---|---|---|---|---|---|---|"]
    for r in ROWS:
        paths="<br>".join("`"+p.removeprefix("asset_library/ittaimanero/sprites/")+"`" for p in r["sources"])
        sizes=sorted({Image.open(ROOT/p).size for p in r["sources"]})
        dims=", ".join(f"{w}x{h}" for w,h in sizes)
        table.append("| " + " | ".join([r["entity"],"<br>".join("`"+p+"`" for p in r["old"]) or "None (procedural / proposed)",
                      paths or "Derived from shared mapped art",r["animation"],dims+" / "+"x".join(map(str,r["cell"])),r["notes"],"YES" if r["gap"] else "No (direct or recombined)"]) + " |")
    table_text="\n".join(table)+"\n"
    (RUN/"mapping_table.md").write_text(table_text,encoding="utf-8")
    notes=(Path(__file__).parent/"mapping_notes.md").read_text(encoding="utf-8")
    (ROOT/"project/art_mapping.md").write_text(notes.replace("<!-- TABLE -->",table_text),encoding="utf-8")
    print(json.dumps(report,indent=2))


if __name__ == "__main__": main()
