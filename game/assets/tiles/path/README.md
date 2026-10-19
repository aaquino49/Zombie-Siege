# Grass-edged dirt path tiles

Native 64x64 Kenney Tower Defense (Top-Down), CC0. Sources are in
`asset_library/kenney/kenney_tower-defense-top-down/PNG/Default size/`.
Angles below are clockwise; no flips, stretching, resampling or geometry edits.
All border tiles apply the same green-only RGB palette remap: `(r*39/46, g*174/204, b*96/113)`,
rounded per channel for pixels with `g > r`. The source grass base `(46,204,113)` becomes
`(39,174,96)`, exactly the base of existing `grass_1..3.png`; brown pixels are unchanged.
Tile 050 is plain dirt `(187,128,68)`, exactly the existing `dirt.png` base and boundary color.
Existing dirt's decorative flecks are intentionally absent from the plain path center.

| File | Kenney source | Rotation / flip | Grass location |
| --- | --- | --- | --- |
| `path_center.png` | `towerDefense_tile050.png` | 0 degrees clockwise; no flip | center |
| `path_edge_n.png` | `towerDefense_tile001.png` | 180 degrees clockwise; no flip | edge_n |
| `path_edge_e.png` | `towerDefense_tile001.png` | 270 degrees clockwise; no flip | edge_e |
| `path_edge_s.png` | `towerDefense_tile001.png` | 0 degrees clockwise; no flip | edge_s |
| `path_edge_w.png` | `towerDefense_tile001.png` | 90 degrees clockwise; no flip | edge_w |
| `path_outer_ne.png` | `towerDefense_tile003.png` | 90 degrees clockwise; no flip | outer_ne |
| `path_outer_nw.png` | `towerDefense_tile003.png` | 0 degrees clockwise; no flip | outer_nw |
| `path_outer_se.png` | `towerDefense_tile003.png` | 180 degrees clockwise; no flip | outer_se |
| `path_outer_sw.png` | `towerDefense_tile003.png` | 270 degrees clockwise; no flip | outer_sw |
| `path_inner_ne.png` | `towerDefense_tile002.png` | 180 degrees clockwise; no flip | inner_ne |
| `path_inner_nw.png` | `towerDefense_tile002.png` | 90 degrees clockwise; no flip | inner_nw |
| `path_inner_se.png` | `towerDefense_tile002.png` | 270 degrees clockwise; no flip | inner_se |
| `path_inner_sw.png` | `towerDefense_tile002.png` | 0 degrees clockwise; no flip | inner_sw |

## Neighbour rule for T-071

For each path tile, inspect the four orthogonal neighbours. Path, DIRT, and out of bounds count as dirt; GRASS counts as grass.
- 0 grass sides: `path_center.png`, unless exactly one diagonal neighbour is grass, then `path_inner_<diagonal>.png`.
- 1 grass side: `path_edge_<side>.png`.
- 2 adjacent grass sides: `path_outer_<corner>.png`.
- Anything else cannot occur with 2-wide paths; fall back to `path_center.png`.

N = up, E = right, S = down, W = left. Corner names identify grass, not the direction dirt extends.
The contact sheet is built directly from this rule; outside its map bounds counts as dirt.
