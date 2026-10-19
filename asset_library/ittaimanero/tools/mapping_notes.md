# Zombie Siege — Ittai Manero entity mapping (T-101)

Mapping proposal for quarterback review before any swap. No files under `game/` are changed. The task brief and the rewritten Art Guide override the role guide's older Kenney/copy/import instructions. Source paths in the main table are relative to **`asset_library/ittaimanero/sprites/`**; every listed file exists. Current paths are relative to **`game/assets/`**. A GAP row deliberately names reference material, not a nonexistent finished replacement.

The audit covers `world_view.gd`, `path_tiles.gd`, `building_sprites.gd`, `build_mode.gd`, both unit layers, combat FX, helicopter, selection/HP/text presentation, all UI scenes, `ASSET_INDEX.md`, and the building/zombie/balance data. There are **12 building types total** (Command Center plus 11), **7 survivor variants**, and **3 active zombie types**. Guard post is a logical guard position, not a placeable building or currently drawn sprite. Curated-but-unused PNGs and proposed pack props are identified as such instead of inventing current uses.

Review artifacts:

- `asset_library/ittaimanero/mapping_contact_sheet.png` and identical `project/runs/T-101/a1/contact_sheet.png`: every table row, old next to proposed, all sprite pixels enlarged exactly **4x NEAREST**. The old 1280x720 title is the sole labelled overview thumbnail because it is a composed scene rather than a tile. Old sprites retain their native PNG sizes, so a 128px old building looks four times wider than a 32px replacement; this sheet compares source art, not their final in-game scale.
- `project/runs/T-101/a1/contact_pages/page_01.png` through `page_28.png`: four rows per page for readable review of the very tall master sheet. Empty old panels explicitly say no current sprite. GAP panels show reference sprites or labelled recolour studies; none claims to be finished gap art.
- `project/runs/T-101/a1/frame_alignment.png` and `walk_alignment.gif`: all three native walk facings, fixed 16x16 cells, common foot baseline. Main contact sheet shows down, left, up and mirrored right for each character.
- `asset_library/ittaimanero/mapping_manifest.json`: complete machine-readable rows, exact paths, dimensions, animation counts and gap flags. `project/runs/T-101/a1/mapping_validation.json` records coverage and path checks.
- `asset_library/ittaimanero/palette.png`: **41 opaque pack colours**, one native pixel per colour. `palette.json` stores RGB hex values, including colours from the inventory additions. Do not enlarge this source palette file in game.

Rebuild from repo root: `python asset_library/ittaimanero/tools/build_mapping.py` (Pillow). Mapping data and prose are kept beside that script. It writes only `asset_library/` and the task run folder; `project/art_mapping.md` is assembled from this preamble, its generated table, and the ending notes below.

## Entity inventory

`Native size / padded cell` lists the actual dimensions found among the referenced source pieces, followed by the proposed common output cell. Composite buildings are assembled from 16px-wide modules; top/bottom pieces are legitimately trimmed to 7–9px height. A tower's 32x48 visual is not a 2x3 collision footprint. All anchors are the bottom-centre of the stated logical footprint, with roof overhang above and y-sort by the feet/footprint baseline. In T-102 onward all world images stay native, scale by exactly 4, and use nearest filtering.

<!-- TABLE -->

## Exact animation selections and fallbacks

All filenames in this section use the table's exact folders and the naming formula `Zombie-Tileset---_<Capa number minus one, four digits>_Capa-<number>.png`. Ranges are inclusive and ordered by increasing number. The **native side faces LEFT**, as verified on the enlarged face/arm silhouettes; RIGHT is `flip_h` of LEFT. Do not rotate any body sprite. All body frames, including Kid and Big, are padded to **16x16**. Big is wider naturally; do not retain old 1.5x brute scaling or 0.9x runner scaling.

| Body / role | Walk down | Walk left | Walk up | Hurt down | Hurt left | Hurt up | Right |
|---|---|---|---|---|---|---|---|
| Player / all survivors | 477–479 | 480–482 | 483–485 | 486–488 | 489–491 | 492–494 | Mirror left |
| Skinny / walker | 395–397 | 398–400 | 401–403 | 404–406 | 407–409 | 410–412 | Mirror left |
| Kid / runner | 431–433 | 434–436 | 437–439 | 440–442 | 443–445 | 446–448 | Mirror left |
| Big / brute | 413–415 | 416–418 | 419–421 | 422–424 | 425–427 | 428–430 | Mirror left |
| Turret Zombie / spare only | 449–452 | 453–456 | 457–460 | 461–463 | 464–466 | 467–469 | Mirror left |

For Player/Skinny/Kid/Big, first frame in each facing is the neutral/standing pose; the next two are opposite strides. The review filmstrip uses **0,1,0,2** (four playback slots, three unique source frames), returning through neutral between strides. Pad first, then mirror the entire cell; do not independently centre a mirrored trimmed image. Turret spare uses all four source walk frames in ascending order.

| Runtime animation | Frames per direction | Source and handling | FPS / loop |
|---|---|---|---|
| `idle_down/up/left/right` | 1 | First walk frame of that facing; right mirrored | 4 / yes |
| `walk_down/up/left/right` | 3 unique (4 playback slots), spare 4 | Ranges above | 8 / yes |
| Survivor `attack_<dir>` (shoot) | 1 body + FX | Neutral body + pistol 371–375 overlay, with pistol 335 if weapon is shown; shotgun 365–370 optional | 10 / once |
| Survivor knife attack overlay | 1 body + 4 FX | Neutral body + slash 376–379; **not four character poses** | 10 / once |
| Zombie `attack_<dir>` | 3 unique, spare 4 | Walk frames at attack rate plus short target-directed lunge | 10 / once |
| `hurt_<dir>` | 3 | That facing's red, black silhouette, pale flash in listed order; do not recolour these by shirt mask | 12 / once |
| `death` | 1 + 5 | Down red frame: Player 486 / Skinny 404 / Kid 440 / Big 422 / spare 461, then blood 380–384, then 0.5s runtime fade | 10 / once |

The pack supplies **no dedicated idle, body attack or death poses**. The above are the Art Guide's approved fallback recipes, not additional art gaps. Dead corpses are optional persistent decals: prone 291/294/296 and seated 292/293/295 are separate three-frame fly loops, never one six-frame body-morph sequence. Turret vomit 470–476 is an optional seven-stage projectile, not turret building art or a body animation. Pistol/shotgun/slash effects are direction-independent overlays; FX may rotate. Helicopter and turret building headings remain gaps, so the sheet does not invent directional frames for them.

## Verified alignment approach

`psd-tools` inspection of `Zombie Apocalypse Tileset.psd` found **12 raster layers**, including `Layer 3`, `Layer 2`, `Layer 18`, `GAS TOP`, `GAS MIDDLE`, `GAS BOTTOM`, `LETRAS` and `NUMEROS`; **no `Capa-###` layers**. Bounds are retained in `project/runs/T-101/a1/psd_layers.json`. The PSD is a partially flattened reference layout, and its group offsets cannot reliably recover individual Capa-frame registration. This is the documented reason for choosing the Art Guide's fallback, not an untested assumption about matching names.

Verified example: Player down **477 = 14x16 → (x=1,y=0)** in a 16x16 cell; **478 and 479 = 14x15 → (1,1)**. Every cell uses integer `x=(16-width)//2`, `y=16-height`, leaving the common foot boundary at y=16. Skinny left **398 = 10x16 → (3,0)**, **399 = 9x15 → (3,1)**, **400 = 11x15 → (2,1)**. The 4x baseline filmstrip shows no padding-induced vertical drift; the pack's one-pixel torso bob and stride/arm movement remain. This is a practical foot-anchored fallback, not recovered PSD-perfect pivots. Later sprite import should preserve these exact padding coordinates. An asymmetric side frame can move its torso within the cell during a step; do not erase that authored movement with per-frame silhouette centring.

Modular building compositions in the sheet use the exact placement rows described in the entity table; verify roof/front joins against the reference sheet rather than bottom-centre-padding each tile independently. Command Center is 32x48 with a **32x32 logical footprint** (bottom 32px), while Shelter/Farm/Lumber Yard use 32x32 cells and footprints. Watchtower is a 16x32 visual with a 16x16 footprint. Helicopter body and rotor will share an explicit source-space hub at (24,16) and (24,24) respectively, not independently alpha-trimmed centres.

## Terrain and barrier joins

The current T-071 renderer has **13 material-boundary tiles**: centre, four grass edges, four convex corners, four concave notches. It does **not** have separately drawn straight/end/T-junction assets: those are emergent neighbour configurations, and some narrow-track masks currently fall back to centre. The table maps every actual old tile individually, then lists the native narrow-path alternatives and optional asphalt vocabulary.

Native dirt connectivity, verified by inspecting the sand pixels touching each edge:

| Shape | Capa | Connected path edges |
|---|---|---|
| isolated round patch | 66 | none |
| cross | 67 | N,E,S,W |
| straight | 68 / 69 | E,W / N,S |
| corner | 71 / 72 / 74 / 75 | N,W / S,W / N,E / S,E |
| T | 70 / 73 / 76 / 77 | N,S,W / E,S,W / N,E,S / N,E,W |

There are no native one-sided end caps or broad all-sand centre tile. Recombine round 66 with clipped 68/69 for ends; derive all-sand fill from the existing path centre colour (#77664e). For the old boundary atlas, expand the native sand region to the connected sides over ground 78, preserving grass on the named edges/corner. The sheet's derived boundary studies use **3px ground edge bands / 3x3 concave ground corners**; these are explicit recombinations rather than a claim that the native narrow path is a drop-in 13-tile atlas. Final jagged transitions can copy the same source contour pixels; no new palette or additional terrain art gap is needed. Clearing uses the same material as dirt. Optional asphalt requires separate connectivity assembly using Road edge/marking pieces over 54; it does not replace dirt tracks by accident.

Wood fences: EW rails 208/214, NS rails 210/211, end posts 207/209 and lower-corner posts 213/215; use 212 as the central upright. Place a shared upright at every crossing, cut half rails from the straight sources and join to it for corners/T/cross; preserve the upright's full front-facing height. A closed gate inserts a removable rail segment between two posts; open gate keeps only those posts. None of these edits rotates a finished sprite. Terrain wall 65 repeats EW; cuts of its top rim and earth face form NS/end/corner/T pieces without changing collision. The fence/world-side assemblies are processing work in later swaps, not missing source artwork. A dedicated damaged wall state is not in the pack; normal art + HP bar is sufficient, with optional debris/smoke already mapped.

## Survivor looks and UI handoff

Retain every balance-data variant. Review shirt studies use pack RGBs: blue #878c96, brown #866752, green #949974, old #b6aeae (also grey hair), survivor #c36448, hitman #211818, soldier #928969. Those names are identifiers; the pack's muted blue is only a small source accent. Final semantic masks recolour **shirt cloth only**, preserve white eyes/highlights and black outlines, and add pack-compatible hair/skin changes where useful. One `SpriteFrames` per variant shares the exact frame layout. Hurt silhouettes stay authored; do not tint the entire texture. The sheet's white-to-shirt replacements are labelled **studies**, not final semantic recolour masks.

For T-108, `UI Elements` supplies dotted 16x16 slots (499,502), 0–9 digit sprites (504–513), colon (514), a currency glyph (519), small battery-like symbols (517,518), and a handful of baked English labels. **It supplies neither a complete alphabet nor a font file, complete HUD panels, or button-state art.** `Inventory interface/EMPTY_SLOT.png` gives the solid chamfered **32x22** frame: use a 9-slice with 6px source corner margins; tile the border segments at integer scale. `USING_SLOT.png` supplies the selected outline. Other 32x22 files provide weapon/medicine/radio/ammo icons embedded in slots, which can be extracted for HUD use. `INTERFACE WITH NEW INVENTORY.png` is a flattened **480x270** layout reference and should not ship as the whole UI. Normal/hover/pressed buttons are derivable from EMPTY/USING + palette remap, so they do not need a separate gap. Digit sprites are not an adequate general-purpose text font; font acquisition is grouped with the UI gaps below.

## Gap list

These are **nine gap families**, with several table rows sharing one family. No gap is raised for construction/damaged variants, missing body attack/death poses, road mask processing, lumber yard, title scene, shadow or app icon: the mapped processing/fallbacks cover those needs.

| Gap | Why nothing direct is usable | Planned approach / target |
|---|---|---|
| **Turret building** | Turret Zombie is an organic enemy; no emplacement/base/barrel set exists. | Edit pistol 335 / shotgun 332 and round Road detail 55 into an outlined mount, four aimed barrel facings; 16x16 footprint/cell. |
| **Radio tower** | Radios 356/357 are handheld; windmill is not a radio mast. | Shelter/building base + fence-post lattice (210/211), hand-edit antenna and radio details; 32x48 cell, 32x32 footprint. |
| **Watchtower** | No elevated deck, support legs or protected guard platform. | Fence rails/posts 207/209/210/211/214 edited into raised wooden deck; 16x32 cell, 16x16 footprint. |
| **Guard post** | No existing drawn post; logical guard positions are currently unmarked. | Low cover made from fence 207/209/208 and tire 193, hand-edit guard marker if later task needs one; 16x16. Not a new simulation building. |
| **Survivor variants (all seven)** | One player body; no alternate clothing/hair/skin identities. | Semantic shirt/hair/skin masks and in-palette recolours of 477–485; preserve hurt/FX recipes and 16x16 feet alignment. Seven studies are shown for review. |
| **Rocks (two looks)** | No rock/boulder category; tree stumps, straw and earth wall do not read as impassable stones. | Hand-edit broken debris 290 / wall 65 shapes into angular grey boulders with pack outline; two 16x16 looks. |
| **Rescue helicopter (body + rotor)** | Cars/tractor are ground vehicles; windmill fan is vertical. No aircraft exists. | Use Car 167/171 and fan 221/223–225 only as material cues, hand-place a 3/4 fuselage/tail/skids and horizontal rotor in pack palette. Body 48x32, rotor 48x48, four body headings and three rotor phases; shared hub. |
| **UI transport symbols (pause/play/fast)** | No control-symbol glyphs in UI Elements or inventory slots. | Hand-place 8x8 bars/triangle/double triangle from existing off-white/outline colours; reused by all speeds. |
| **General UI font** | Only digits and a few baked labels; no font file or complete alphabet. | T-108 acquires a readable OFL pixel font and retains its licence locally, or hand-builds a complete glyph atlas. Do not pretend the pack contains a full font. Exact external font choice belongs to that task. |
