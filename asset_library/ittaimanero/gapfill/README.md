# T-118 native pixel gap-fill

From the repository root, with Python and Pillow:

```powershell
python asset_library/ittaimanero/gapfill/build_all.py
godot --headless --path game --import
python asset_library/ittaimanero/gapfill/build_all.py --check-imports
```

The six independent recipes are `survivors.py`, `turret.py`, `radio_tower.py`,
`watchtower.py`, `rocks.py`, and `helicopter.py`. Each can be run directly to rebuild
its PNG family; `build_all.py` also refreshes the manifest, asset index, credit
section, validation and review artifacts. Sources are resolved by unique Capa IDs.
`common.py` asserts all visible RGBs belong to `palette.json`, alpha is 0/255 and
the pack black outline is present, printing the result for every output.

68 PNGs: 56 survivor strips, five turret layers, two towers, two rocks and three
helicopter files. Character strips have three 16x16 cells in T-102's exact padding.
Walk sequence 0-1-0-2 at 8fps. Hurt sequence 0-1-2 at 12fps; red/black/white authored
silhouettes are unchanged. Hair masks affect enclosed crown pixels only, preserving
eyes and outline; shirt mask selects authored white cloth; trousers remain intact.
The sprite has black eyes and no separate white eye/highlight pixels.

Turret pivot is (8,8). Radio/watchtower footprints are the bottom 32x32/16x16 regions
of 32x48/16x32 cells, anchors (16,48)/(8,32). Helicopter body hub (24,16), rotor hub
(24,24); compose by placing the body at (0,8) in the rotor's 48x48 cell. The whole-cell
right body is the mirror of left. The mast straddles the central mirror axis. Rotor
phases have a fixed hub and authored integer pixel endpoints on the horizontal plane.

All review sprite pixels are 4x Nearest. Review `contact_sheet.png`, smaller family
sheets, `survivor_walk.gif`, and `walk_alignment.png` in `project/runs/T-118/a1/`.
`asset_validation.json` checks dimensions, palette, alpha, unique variants, exact
player silhouettes/hurt, mirrors and rotor hub. `--check-imports` checks all 68
lossless imports, no mipmaps/resize and the project's Nearest default.

`manifest.json` lists actual donors/material references, processing, dimensions,
footprints, pivots, hubs and SHA-256 of each PNG. No AI generation, antialiasing,
rotation or resampling is used in shipped files. Tall footprints stay at the bottom.
No raw pack files, spare guard-post art, UI art, `.gd` or `.tscn` are produced.
