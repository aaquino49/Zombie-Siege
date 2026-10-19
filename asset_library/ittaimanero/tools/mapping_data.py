"""T-101 review data. IDs are real Capa numbers, never proposed file names."""
ROWS = []


def row(entity, old, ids, cell, notes, gap=False, animation="1 x 1", preview=None):
    ROWS.append(dict(entity=entity, old=old.split(';') if old else [], ids=ids,
                     cell=cell, notes=notes, gap=gap, animation=animation,
                     preview=preview))


def terrain():
    for i, n in enumerate([78, 79, 80], 1):
        row(f"grass_{i}", f"tiles/grass_{i}.png", [n], [16, 16],
            "Opaque brown/olive pack ground; retain pack palette, no invented green tint.")
    row("grass extra variant", "", [81], [16, 16], "Optional fourth base variant.")
    row("flower decals", "", [118, 218], [16, 16], "Full grass-with-flowers tiles; use intact tiles, or mask flowers only.")
    row("tuft decals", "", [80, 81], [16, 16], "Extract black blade clusters, preserving coordinates; optional overlay.")
    for name in ["dirt", "dirt_2", "clearing"]:
        row(name, "tiles/" + ("dirt.png" if name == "clearing" else name + ".png"),
            [66, 68, 78], [16, 16], "Derive opaque fill from path sand colour; keep 78 speckles only for dirt_2. Clearing uses same dirt material.", preview="dirt")
    # PathTiles actually has 13 material-boundary tiles, not a 16-mask road atlas.
    paths = {"center": [66, 68], "edge_n": [68], "edge_e": [69],
             "edge_s": [68], "edge_w": [69], "outer_ne": [72],
             "outer_nw": [75], "outer_se": [71], "outer_sw": [74],
             "inner_ne": [72], "inner_nw": [75], "inner_se": [71], "inner_sw": [74]}
    for suffix, ids in paths.items():
        row("path_" + suffix, "tiles/path/path_" + suffix + ".png", ids + [78], [16, 16],
            "Derived material boundary, not direct substitution: expand sand mask to connected edges; see path recipe. No sprite rotation.", preview="path_" + suffix)
    for name, ids in {"straight_ew": [68], "straight_ns": [69], "corner_sw": [72],
                      "corner_se": [75], "corner_nw": [71], "corner_ne": [74],
                      "end": [66, 68, 69], "junction_nes": [76],
                      "junction_esw": [73], "junction_nsw": [70],
                      "junction_new": [77], "cross": [67]}.items():
        row("path topology " + name, "", ids, [16, 16],
            "Native narrow-track option; end is cut from straight plus round 66 cap. Existing renderer uses boundary tiles above.")
    for name, ids in {"straight": [30, 35, 40, 45, 46, 47], "corner": [31, 32, 33, 34],
                      "end": [41, 42, 43, 44, 54], "junction": [48, 49, 50, 51, 52]}.items():
        row("asphalt road " + name, "", ids, [16, 16],
            "Optional decorative asphalt atlas. Ends/junctions recombine edge/marking pieces over 54; not used by current dirt roads.")


def world():
    for i, ids in [(1, [135, 138]), (2, [137, 138])]:
        row(f"tree_{i}", f"props/tree_{i}.png", ids, [16, 32],
            "Stack crown at (0,0), trunk at (0,16); 1x1 collision footprint, bottom-centre anchor.", preview="tree")
    for i in [1, 2]:
        row(f"rock_{i}", f"props/rock_{i}.png", [290, 65], [16, 16],
            "No rock category or readable boulder in pack. Hand-edit debris 290 into grey angular stone using existing grey/brown palette.", True)
    row("scrap_1", "props/scrap_1.png", [289, 290, 193], [16, 16], "Item box plus broken debris/tire; 1x1 salvage pile.")
    row("scrap_2", "props/scrap_2.png", [192, 193, 194], [32, 16], "Wreck debris (27x11) and tires, centred over 1x1 footprint; overhang does not block adjacent cells.")
    row("scrap_3", "props/scrap_3.png", [193, 194, 290], [16, 16], "Tire/debris cluster; 1x1 salvage pile.")
    row("command_center", "buildings/command_center.png", [1, 25, 2, 26, 3, 27, 5, 15], [32, 48],
        "2x2 footprint; rows: roof caps [1,25] y0, roof [2,26] y7, eaves/front [3,27] y23, base/door [5,15] y39.", preview="cc")
    row("wooden_wall", "buildings/wall_wood.png", list(range(207, 218)), [16, 16],
        "1x1 footprint; horizontal 208/214, vertical 210/211; terminal posts 207/209/213/215, centre-post 212. Composite corners/T/cross; see fence recipe.")
    row("gate", "buildings/gate.png", [208, 210, 211, 212, 214], [16, 16],
        "1x1; closed gate = cropped rails 208 between vertical posts 210/211; open = posts only. NS uses vertical rails edited from same pixels.")
    row("reinforced_wall", "buildings/wall_reinforced.png", [65], [16, 16],
        "1x1; Terrain wall is a raised earth face, not metal. Tile face EW; NS/corners/T use cuts of top rim and face; preserve 3/4 top rim.")
    row("shelter", "buildings/shelter.png", [94, 104, 93, 105, 92, 98], [32, 32],
        "2x2; cap [94,104] y0, walls [93,105] y7, base/door [92,98] y23.", preview="shelter")
    row("farm", "buildings/farm.png", [270, 268, 110, 111], [32, 32],
        "2x2; one-column barn roof 270 (0,0), shutter wall 268 (0,16); crops 110 (16,0),111 (16,16).", preview="farm")
    row("storage", "buildings/storage.png", [1, 25, 2, 26, 3, 27, 5, 24, 119], [32, 48],
        "2x2; CC shell, replace front-right base with 24 shutter; straw stack 119 in front-left as supplies.", preview="storage")
    row("watchtower", "buildings/watchtower.png", [207, 209, 210, 211, 214], [16, 32],
        "1x1; no elevated guard platform. Edit fence posts into four legs, add raised deck/rail; protect guard silhouette.", True)
    row("workshop", "buildings/workshop.png", [1, 25, 2, 26, 19, 27, 5, 15, 193], [32, 48],
        "2x2; CC shell with grille 19 replacing front-left 3 and tire 193 beside doorway.", preview="workshop")
    row("lumber_yard", "buildings/lumber_yard.png", [94, 104, 93, 105, 92, 103, 140, 141], [32, 32],
        "2x2; small shelter shell with shutter 103; stack cut log 140 and dark log 141 in front. Logs, not straw, identify wood.", preview="lumber")
    row("turret", "buildings/turret_base.png;buildings/turret_barrel.png", [335, 332, 55, 193], [16, 16],
        "1x1; Turret Zombie is a monster, not a gun emplacement. Edit pistol/shotgun hardware onto round base 55; draw four barrel facings, never rotate body.", True, "1 x 4 aimed facings")
    row("radio_tower", "buildings/radio_tower.png", [356, 210, 211, 94, 104], [32, 48],
        "2x2; portable radio is not tower. Recombine shelter base + posts as lattice, hand-edit mast and antenna above; 32x48 anchored to footprint.", True)
    row("guard_post", "", [207, 209, 208, 193], [16, 16],
        "Not a buildings.json type and has no current sprite; guards use logical positions. Future marker needs low barricade/cover, edit fence and tire.", True)
    for size in [1, 2]:
        row(f"construction_{size}x{size}", f"buildings/construction_{size}x{size}.png", [207, 209, 210, 211, 214, 290], [16*size, 16*size],
            "Scaffold alternative composed from fence posts/rails plus debris, below final roof; current renderer instead tints final texture. Reuse per-building footprint, no dedicated pack construction frame.", preview="scaffold")
    row("blueprint / placement ghost", "buildings/command_center.png", [1, 25, 2, 26, 3, 27, 5, 15], [32, 48],
        "Reuse every building's mapped image. Palette-blue outline / valid-invalid footprint outline; runtime transparency only, no antialiased asset.", preview="cc")
    row("damaged building look", "buildings/command_center.png", [103, 24, 290, 385], [32, 48],
        "No damage-state building set; 103/24 are shutters, not destroyed walls. Keep normal art plus HP bar; optional broken debris/blood overlay, no mandatory new damaged sprite.")


def characters():
    for variant in ["blue", "brown", "green", "old", "survivor", "hitman", "soldier"]:
        row("survivor_" + variant, f"characters/survivor_{variant}_stand.png;characters/survivor_{variant}_gun.png",
            list(range(477, 495)) + [335] + list(range(371, 380)), [16, 16],
            "Single player base only. Recolour masked shirt/hair/skin using pack palette; all seven data variants preserved. Walk/hurt directional ranges in animation table. Gun + knife are overlays, no extra poses.",
            True, "walk 3 x 3 native / 4 mirrored; hurt 3 x 3 / 4; idle/attack 1 x 4 derived; death 1+5 x 1", preview="survivor_" + variant)
    for name, start, hurt, size in [("walker",395,404,16),("runner",431,440,16),("brute",413,422,16)]:
        row(name, "characters/zombie_stand.png", list(range(start,start+9))+list(range(hurt,hurt+9))+list(range(380,390)), [size,size],
            "Skinny / Kid / Big respectively; native side faces LEFT; mirror to RIGHT. Idle first walk frame; attack walk + lunge; death down-red hurt + blood + fade. No old tint/fractional size after swap.",
            False, "walk 3 x 3 native / 4 mirrored; hurt 3 x 3 / 4; idle 1 x 4; attack 3 x 4 derived; death 1+5 x 1", preview="actor_"+str(start))
    row("Turret Zombie (spare)", "characters/zombie_hold.png", list(range(449,470))+list(range(470,477)), [16,16],
        "Not currently spawned; zombie_hold is curated unused art. Native side LEFT. Vomit is a 7-frame projectile, not body attack poses.",
        False, "walk 4 x 3 native / 4 mirrored; hurt 3 x 3 / 4; vomit 7 x 1", preview="actor_449")


def props_fx_ui():
    row("bullet / tracer", "fx/bullet.png", [372,373], [16,16], "Current combat tracer is Line2D, bullet PNG unused. Use 373 shot streak or palette line; rotation allowed.")
    row("pistol muzzle flash", "fx/muzzle_flash.png", list(range(371,376)), [16,16], "5 FX stages, not character poses; right-facing streak 372/373, burst 371; rotate overlay to target.", animation="5 x 1 (FX rotation)")
    row("shotgun muzzle flash", "fx/muzzle_flash.png", list(range(365,371)), [16,16], "6 FX stages, overlay only; no shotgun weapon mechanic needed for mapping.", animation="6 x 1 (FX rotation)")
    row("knife slash", "", list(range(376,380)), [16,16], "4 slash-overlay stages; stand pose remains player idle. Optional FX.", animation="4 x 1 (FX rotation)")
    row("blood impact", "", list(range(380,385)), [16,16], "5 stages; bottom-centre at hit/death feet.", animation="5 x 1")
    row("blood stains", "", list(range(385,390)), [16,16], "5 static variants, no animation.")
    row("corpses with flies", "", list(range(291,297)), [16,16], "Two bodies: prone 291/294/296; seated 292/293/295. Do not cycle all six as one corpse (pose changes).", animation="3 x 1 each of 2 bodies")
    row("explosion", "", list(range(359,365)), [16,16], "6 burst stages; optional building-destruction FX.", animation="6 x 1")
    row("smoke", "", list(range(322,328)), [16,16], "6 smoke stages; optional workshop/ruins FX.", animation="6 x 1")
    row("wrecked cars / tires", "props/scrap_2.png", list(range(180,195)), [48,48], "Three car colours x four views (180-191), debris 192, tires 193/194; intact car is decoration, salvage pile uses cropped debris. No rotation.")
    row("barrels", "", list(range(147,151)), [16,16], "4 barrel damage/explosion states; not 4 directions.", animation="4 x 1")
    row("signs", "", [151,152,153,155,156,158,159,160], [16,16], "Road signs/barricade; generic sign 153. Existing art contains pictograms, keep without baking new game text.")
    row("bushes", "", list(range(82,92)), [16,16], "Corners/centre of modular hedge; 84/90 half-width caps. Optional static decals.")
    row("straw", "", list(range(119,125)), [16,16], "Static stack plus side/top cuts; optional farm prop.")
    row("rescue helicopter body", "fx/helicopter_body.png", [167,171,221], [48,32], "No helicopter or aircraft. Hand-edit car fuselage into 3/4 helicopter with skids/cockpit/tail; car is material reference only. Four discrete headings.", True, "1 x 4")
    row("rescue helicopter rotor", "fx/helicopter_rotor.png", [223,224,225], [48,48], "Windmill fan is vertical, cannot be a top rotor unchanged. Hand-edit horizontal rotor, discrete blade phases; retain hub coordinate with body, no continuous rotation.", True, "3 x 1 phases")
    row("rescue helicopter shadow", "fx/helicopter_body.png", [167], [48,32], "Reuse final helicopter alpha as runtime shadow at reduced opacity; no separate missing art.")
    row("UI panels", "ui/panel.png;ui/panel_wide.png", [499,502], [32,22], "UI Elements has dotted square inventory frames, not solid large panels. Best 9-slice basis is EMPTY_SLOT (32x22), corner margins 6 source px.", preview="ui_panel")
    row("inventory slots", "", [499,502], [32,22], "Use all 32x22 item slots; USING_SLOT is selection border; INTERFACE WITH NEW INVENTORY is a flattened 480x270 mockup, not a runtime panel.", preview="inventory")
    row("UI button normal", "ui/button_normal.png", [], [32,22], "Derive solid 9-slice button from EMPTY_SLOT; no standalone button PNG in pack.", preview="ui_panel")
    row("UI button hover", "ui/button_hover.png", [], [32,22], "Overlay USING_SLOT highlight on EMPTY_SLOT; no dedicated hover sprite.", preview="ui_hover")
    row("UI button pressed", "ui/button_pressed.png", [], [32,22], "Palette-remap EMPTY_SLOT interior darker and inset content 1 source px; no dedicated pressed sprite.", preview="ui_pressed")
    row("UI health/progress bar background", "ui/bar_background.png", [499,517,518], [32,6], "Cut existing outlined slot into narrow 9-slice bar; pack 517/518 are battery-like glyphs, not full bars.", preview="bar_bg")
    row("UI health/progress bar fill", "ui/bar_fill.png", [517], [30,4], "Solid pack colour fill; HP/progress semantics remain procedural, no missing art.", preview="bar_fill")
    for name, ids in [("food",[329,330,331]),("wood",[140]),("scrap",[193,194]),("ammo",[343,344,345])]:
        row("HUD icon " + name, "icons/icon_"+name+".png", ids, [16,16], "Food uses drumstick/food, wood a cut log, scrap tire, ammo cartridges; native glyphs padded, never Lanczos.")
    for name in ["pause","play","fast"]:
        row("HUD icon " + name, "icons/icon_"+name+".png", [499], [8,8], "No transport controls. Hand-place 2 bars / triangle / double triangle using outline and off-white pack colours.", True)
    row("UI digits / labels / font", "", list(range(495,499))+list(range(503,520)), [40,16], "Digits 0-9 are 504-513 (individual 8x8 cells), colon 514, a few baked labels 495-498/503/515/516. No complete alphabet, font file or readable full UI font.", True)
    row("title scene", "ui/title_art.png", [78,1,25,2,26,3,27,5,15,395,477], [64,48], "Replace old static 1280x720 image with live siege composition of mapped entities in menu task. Contact sheet uses labelled overview thumbnail, no full-size new title asset.", preview="title")
    row("application icon", "icon/icon.png", [356,1,25,2,26,3,27,5,15], [32,32], "Compose CC silhouette + radio glyph at integer native size; reuse approved tower vocabulary. ICO derived later; no independent gap.", preview="icon")
    row("HP bars / progress indicators", "", [517,518], [16,4], "Currently procedural coloured rectangles; theme same procedural primitives with existing pack colours.", preview="bar_fill")
    row("selection / placement outlines", "", [499], [16,16], "Procedural ring/rect outlines; redraw pixel-stepped outline using pack colours. No texture gap.", preview="outline")
    row("floating text / phase banners / screen tint", "", [504,505,506,507,508,509,510,511,512,513], [16,16], "Procedural Labels and CanvasModulate; use chosen UI font + palette colours. No additional sprite, font gap shared above.")


terrain()
world()
characters()
props_fx_ui()
