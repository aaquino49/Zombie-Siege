# Pixel UI handoff (T-108)

This kit is staged for T-109's Theme and T-110's menus. Current UI assets remain
in use. All 27 PNGs are native pixels with binary transparency and pack colours.
No labels are baked in. Do not resample or fractionally scale them.

- Panel, inset, tooltip, five button states: **32x22**, slice margins
  **L=6, T=6, R=6, B=6 source px**. Frame is based on EMPTY_SLOT's opposite
  chamfers with its dotted detail; missing straight side runs are closed.
  Pressed/toggle have a one-source-pixel dark inset bevel. Hover has cream trim;
  toggle has olive trim; disabled has subdued dark trim.
- Slider track and bar background: **32x6**, margins **2,2,2,2**.
- Slider/bar fill: **8x4**, margins **1,1,1,1**. Olive bar fill is the neutral HP
  and construction-progress colour; keep any semantic tint within pack colours.
- Grabber/hover: **8x12**, fixed size. Checkbox off/on: **12x12**, fixed size.
- Food, wood, scrap, ammo, survivors, day, night: **16x16**, fixed size.
  Pause, play, fast (two triangles), faster (three): **8x8**, fixed size.

Use Nearest and integer 4x display scale. Slice margins describe source regions,
not content padding. Preserve the fixed corner regions at 4x screen size and
tile edge/centre regions. The review sheet demonstrates 200x48 and 400x300
screen targets (50x12 and 100x75 native). A 48px button leaves no vertical centre
region with 24px corners; labels need independent padding/layout appropriate
to their font size. No texture scaling or text positioning is wired in here.

`font/siege_pixel.ttf` is the runtime OFL font, with distinct tabular digits.
The theme and explicit HUD font use `font/siege_pixel_noliga.tres`, a
FontVariation wrapping that TTF with `liga` and `clig` disabled so "fi" and "fl"
remain separate letters. The feature keys are integer OpenType tags.
Use UiFont sizes (11/22/33/44/66px) without scaling text.
`font/pixelify_sans.ttf` remains only as the unchanged generator source.
The importer explicitly disables antialiasing, hinting, subpixel positioning,
MSDF, mipmaps and system fallback, with oversampling 1. Fonts use actual UI px
sizes; do not additionally scale the text by four when setting these sizes.
The complete copyright and OFL 1.1 terms are in `font/OFL.txt`.

Coverage is checked in the font's cmap for A-Z, a-z, 0-9 and
`: , . ' ! ? - – ( ) / % + ×`. Review both the 4x inspection samples and
`project/runs/T-108/a1/font_actual_sizes.png` for the true 16/20/32/48px text.
Both required phrases are rendered at every size in the contact sheet.

Rebuild art/sheets: `python asset_library/ittaimanero/gapfill/ui_glyphs.py`
(Pillow + fontTools). The script validates all shipping pixels against
`asset_library/ittaimanero/palette.json`, binary alpha, font coverage/OFL and
exact preservation of all four slice corners at both target sizes.
Per-file donors, processing and hashes live in
`asset_library/ittaimanero/gapfill/ui_manifest.json` and `ASSET_INDEX.md`.
Re-import with `godot --headless --path game --import`.

T-143 wood/scrap polish: after the base kit recipe, run
`python asset_library/ittaimanero/gapfill/resource_icon_outline.py`, then
`python asset_library/ittaimanero/gapfill/ui_x2.py`. The two resource icons keep
their native 16x16 cells and black contours, with a thin exterior cream rim;
scrap mid-tones advance one step along the pack's warm material ramp. Enclosed
openings remain transparent. The x2 cost icons are exact nearest-neighbor
copies; the runtime cream backing remains in place.

## T-224 M12 mood and research icons

Eight new **16x16** RGBA icons use binary alpha and the pack palette, with
one-source-pixel black outlines. Each `x2/` counterpart is an exact **32x32
Nearest 2x** copy; display UI at 2x as specified by the current art guide.

| Native file (matching x2 file) | Meaning / silhouette |
| --- | --- |
| `icon_mood_inspired.png` | Inspired: olive badge, raised eyes and broad open smile |
| `icon_mood_steady.png` | Steady: neutral badge, level eyes and flat mouth |
| `icon_mood_low.png` | Low: muted badge, lowered eyes and arched frown |
| `icon_mood_breaking.png` | Breaking: red badge, cracked forehead, slanted eyes and bright tear |
| `icon_research.png` | Research points: wide-bottom laboratory flask |
| `icon_tech_defense.png` | Defense: pointed metal shield |
| `icon_tech_economy.png` | Economy: horizontal hammer head and wooden handle |
| `icon_tech_survivors.png` | Survivors: two staggered heads and shoulders |

Mood expressions remain different at 1x on `panel.png` and in greyscale.
These assets are staged for M12 integration; this batch changes no game code.
Rebuild only this batch with `python asset_library/ittaimanero/gapfill/m12_batch.py`.
The T-224 contact sheet shows native/2x icons on the current panel, greyscale
moods, and the building assets at native/4x scale in day and night scenes.
Per-file sources and validation: `asset_library/ittaimanero/gapfill/m12_manifest.json`.
Do not run the older base UI generator to rebuild these new glyphs.

## T-214 tech upgrade icons

Nine new **16x16** native RGBA icons live in `tech/`; matching **32x32**
files in `x2/tech/` are exact Nearest 2x copies. Filenames are upgrade ids
from GDD section 23.3. Use Nearest at integer scale; no baked-in labels.
Binary alpha, pack colours and one-source-pixel black outlines match T-224.

| Native tech file (same name in x2/tech) | Meaning / silhouette |
| --- | --- |
| `spotters.png` | Paired binocular barrels |
| `oiled_turrets.png` | Oil can with separate drop |
| `reinforced_frames.png` | Two fence rails with bolted metal braces |
| `better_tools.png` | Crossed axe and wrench |
| `crop_rotation.png` | Wheat stalks with a return arrow |
| `ammo_press.png` | Three cartridges in a wooden loading tray |
| `camp_songs.png` | Flame with musical note |
| `first_aid.png` | Olive medical kit with red cross |
| `bunk_beds.png` | Two-level bed with pillows and blankets |

Defense shares the shield's grey metal ramp; Economy shares the hammer's
warm brown handle ramp with metal accents; Survivors shares the branch's
olive/cream shoulders. Tier order per column is the table order above.

Pack parts are cropped/recombined for the rails, stalks, cartridges and
medical kit; missing motifs use hand-placed pixels in the same palette.
Only processed assets ship. See `project/runs/T-214/a1/README.md` for recipe
commands, exact donor files and visual/pixel validation. The contact sheet
shows each icon at actual 1x/2x on `panel.png`, in greyscale, at 4x for pixel
inspection, and as the 3x3 tech screen next to the three branch headers.
