# Art and Audio Guide

From M6 the game uses Ittai Manero's "Zombie Apocalypse Tileset" (`asset_library/ittaimanero/`, GDD §16). Start with
`Zombie Apocalypse Tileset Reference.png`. The `sprites/` folder has 532 PNGs in 56 named category folders.

## 1. Style

- **16 px pixel art from the pack**, in a **3/4 top-down view** everywhere: roofs and front walls are visible and characters
  are drawn standing up. Never 90° overhead, never isometric.
- Hard-edged pixels only: alpha 0 or 255 (the pack's only exceptions are two shadow pixels). No anti-aliasing, gradients,
  painterly or AI-smoothed art. No baked-in text.
- When M6 ends, no Kenney vector art is left in `game/`. See §10 for the transition.

## 2. Scale and filtering

- **1 source px = 4 screen px** on the 64 px grid. Keep PNGs at native size in `game/` and scale the node
  (`Sprite2D`, `AnimatedSprite2D`, `TileMapLayer` or a shared parent) by `Vector2(4, 4)`. Never pre-upscale PNGs.
- Integer scale only. Use the Nearest filter (the project default, `default_texture_filter=1`), no mipmaps, lossless
  import, no Lanczos, no fractional scale.
- **Never rotate pixel sprites.** Facing comes from the direction animations (§4). The only exceptions are projectiles,
  tracers and muzzle flashes.
- Camera zoom may scale the whole world (0.5×–2×). That is fine, and slight shimmer at non-integer zoom is accepted.
- **UI uses 2×** (1 source px = 2 screen px) for every UI texture: 9-slices, HUD icons and glyphs. At 4× the kit's 6 px
  slice corners and 16 px icons don't fit a 1280×720 HUD. Because `StyleBoxTexture` can't scale, the UI kit ships
  script-generated nearest 2× copies in `pixel/ui/x2/` (the one exception to "never pre-upscale"); the native files stay
  the source. Fonts use real UI px sizes (decided 2026-10-11, T-109).

## 3. Footprints and anchoring

- 1×1 tile = 16×16 source. 2×2 building = 32×32 footprint. Buildings may be taller than their footprint (front wall, roof
  overhang), e.g. 32×48. 1×1 towers may be 16×32.
- **Anchor at the bottom edge of the footprint** (the feet, for characters), and y-sort (`y_sort_enabled` on the parent).
  The overhang drawn above the footprint never blocks clicks or pathing. Footprints are as in GDD §7.
- **Trimmed layers.** Each PNG is a PSD layer trimmed to its content (`Zombie-Tileset---_0476_Capa-477.png`, sizes like
  14×16 or 13×9). Frames in one folder differ in size, and modular pieces carry no position. Recover a common box first:
  1. **Preferred:** read layer offsets from `Zombie Apocalypse Tileset.psd` with Python `psd-tools` (`pip install
     psd-tools`) and re-pad each layer onto a fixed cell at its real offset. Match layers to PNGs by the `Capa-###` name.
  2. **Fallback:** pad each frame **bottom-centre** onto the smallest common cell for its animation. Every character and
     zombie fits **16×16** (largest frame: Big Zombie 16×16). Use 16×24 or larger only if gap-fill art needs it.
  3. Always check the result on a 4× contact sheet: play the frames in order and look for jitter. Modular buildings are
     assembled from 16×16 pieces on a 16 px grid and checked against the reference sheet.

## 4. Animation

- Characters and zombies use `AnimatedSprite2D`, with one `SpriteFrames` `.tres` per character or variant.
- Animation names: `idle_<dir>`, `walk_<dir>`, `attack_<dir>`, `hurt_<dir>`, `death`, with `<dir>` = `down`, `up`,
  `left`, `right`. Pick `<dir>` from the dominant axis of velocity (or of the attack target).
- FPS defaults: idle 4, walk 8, attack 10, hurt 12, death 10. Idle and walk loop. Attack, hurt and death play once.
- **What the pack actually has (checked):**
  - Walk: Player, Skinny, Kid and Big have 9 frames = down, side, up × 3 frames. Turret Zombie has 12 = 3 facings × 4.
  - Damaged (`Damaged * Animation Frames`): Player, Skinny, Kid, Big and Turret have 9 frames = 3 facings × (red tint,
    black silhouette, white flash).
  - **No idle, attack or death frames for anyone.** Knife Attack, Pistol Shooting and Shotgun Shooting are effect
    overlays (slash, muzzle flash, shot), not character poses. The Turret Zombie vomit frames are a projectile.
  - Extras: `Dead Corpses With Flies` (6), `Blood Animation Frames` (5), `Random Blood Stains`, `Sitting Zombie`.
- **Fallback rules, in this order:** (1) `left` = `flip_h` of the side frames (check which way they face). (2) `idle_<dir>` =
  the standing walk frame of that direction, 1 frame. (3) `attack_<dir>` for zombies = the walk frames at 10 fps, and the
  code adds a short lunge toward the target. For survivors it is the standing frame plus a pistol muzzle-flash overlay
  (FX). (4) `hurt_<dir>` = that facing's 3 damaged frames. (5) `death` = the down-facing red-tint frame, then the blood
  frames, then a 0.5 s fade. A corpse decal from `Dead Corpses With Flies` is optional. (6) Only if a rule above looks
  wrong on the contact sheet, gap-fill the frames (§7).

## 5. Entity map defaults

Codex confirms or changes these in the mapping task (T-101). The quarterback approves the mapping at T-101's review.
- **Zombies:** walker → Skinny Walking Zombie, runner → Kid Zombie, brute → Big Zombie. Turret Zombie is a spare.
- **Survivors:** recolors of the pack player (shirt, hair, skin) within the palette, one `SpriteFrames` per variant.
- **Buildings:** Farm → Modular Barns + Different Crops Lengths. Command Center, Shelter, Storage and Workshop → recombined
  Modular Big/Small Building pieces. Walls and gate → Modular Fences. Reinforced wall → Terrain wall.
- **World:** grass → Terrain Variations and Grass with Flowers, paths → Modular Terrain Path, trees → Trees and Modular
  Bushes, scrap piles → Broken Cars and Tires. FX → Blood, Smoke, Explosion and muzzle-flash frames. UI → UI Elements and
  Inventory interface.
- **Known gaps:** turret, radio tower, watchtower, guard post, survivor variants, plus the lumber yard, rescue helicopter
  and app icon if recombining doesn't work.

## 6. Palette

- Use only colours from the pack (about 41 opaque colours across `sprites/`). Codex extracts them to
  `asset_library/ittaimanero/palette.png` (one pixel per colour, in T-101 or T-102).
- Recolors and gap-fill art swap colours within this palette. Never add new colours. Use the pack's black outline.

## 7. Gap-fill process (in this order)

1. Edit or recombine pack pieces (cut, mirror, stack, re-pad).
2. Recolor within the palette.
3. Hand-place 16 px pixel art in the pack palette with a Python PIL script kept in `asset_library/ittaimanero/gapfill/`
   (one script per asset, so it can be re-run). Image generation may be used as a reference only. It never ships.
- Every gap-fill asset gets a 4× contact sheet next to the pack sprites it sits beside in-game, saved in the run folder.

## 8. File layout

```
game/assets/pixel/{terrain,buildings,characters,zombies,props,fx,ui}/
game/assets/pixel/frames/          SpriteFrames .tres, e.g. walker.tres, survivor_a.tres
```
- Readable names: one PNG per frame (`walker_walk_down_0.png`) or a horizontal strip of fixed cells per animation
  (`walker_walk_down.png`). Never use `Capa-###` names in `game/`.
- Every file gets a row in `game/assets/ASSET_INDEX.md` (file, purpose, pack source file(s) and processing).

## 9. Licence

- The pack is free for commercial use and credit is appreciated. **The raw pack may not be redistributed.**
- Ship only the sprites the game uses, processed into `game/assets/pixel/`. The `asset_library/` copy stays out of the
  export (the export preset lives in `game/` and only packs `game/`).
- Credit "Ittai Manero, Zombie Apocalypse Tileset (itch.io)" in `CREDITS.md`.

## 10. Transition

- Until each swap lands, Kenney art and pixel art coexist. Each swap task replaces **one whole area** (terrain, buildings,
  survivors, zombies, props/FX, UI), so styles never mix inside one area.
- The swap removes the Kenney files it replaced (once nothing references them) and their `ASSET_INDEX.md` rows. Kenney
  credits for art are dropped from `CREDITS.md` when the last Kenney image leaves `game/`.

## 11. Audio (unchanged)

- SFX: `asset_library/kenney/kenney_impact-sounds` and `kenney_interface-sounds` (CC0).
- Music and zombie sounds: other **CC0-only** sources (OpenGameArt, freesound CC0), or original sounds synthesised by
  a project script. Keep each licence page in `asset_library/audio/`.
- Files go in `game/assets/sfx/` and `game/assets/music/`. Each file gets an `ASSET_INDEX.md` row and each source is
  credited in `CREDITS.md`.
