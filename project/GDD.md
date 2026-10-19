# Zombie Siege: Game Design Document

Owner: Claude (product manager). Agents follow this doc. If something is unclear, make a reasonable choice, log it in `project/assumptions.md`, and keep going. Only Claude changes this file. Record why in `project/decisions.md`.

## 1. Pitch

A top-down 2D colony survival game for Windows desktop. You lead a small group of survivors around a fortified Command Center. **By day** you gather, build, and assign jobs. **By night** zombie waves attack from the map edges. Survive 20 nights, build the Radio Tower, and hold out until the rescue helicopter arrives.

One full game takes about 40–45 minutes at 1x speed (about 20–23 at 2x). The game is mouse-driven, with keyboard shortcuts.

## 2. Pillars

1. **Readable.** One clear art style (Kenney top-down) and an uncluttered HUD. The player always knows what's happening and why.
2. **Tense nights, busy days.** Each day is a planning puzzle (food vs. walls vs. ammo). Each night tests that plan.
3. **Small and finished over big and broken.** Cut scope before cutting quality. Every milestone must leave the game playable.

## 3. Core loop

```
DAY (planning, 70 s at 1x)            NIGHT (defense, until wave cleared, min 40 s, max 300 s)
- assign survivors to jobs            - zombies spawn at map edges
- place building blueprints           - defenses + guards fight automatically
- gather wood / scrap, farm food      - player can pause, re-assign guards, repair
- craft ammo                          - wave cleared -> DAWN REPORT -> next day
```

If a night reaches 300 s, dawn comes anyway and any zombies still on the map retreat. They don't count as kills. This is a safety net so a stuck zombie can never trap the player in an endless night.

At dawn, a **Dawn Report** panel lists the night's casualties, damage, and zombies killed, plus food eaten and any new survivors who arrived.

## 4. World

- Grid of **64 px tiles**. The map is **48 × 48 tiles**, generated from a seed.
- The **Command Center** (2×2) sits in a clear area at the center of the map.
- Terrain is grass and dirt, with roads for decoration.
  - **Trees** are wood nodes. They're impassable, can be harvested, and run out. They're dense near the map edges.
  - **Scrap piles** are scrap nodes (20–30 piles, 25–45 scrap each). Wrecked cars and debris are scattered across the map, with more of them farther from the center.
  - **Rocks** are impassable decoration.
- Zombies spawn just outside the map's edge tiles.
- Fog of war: none (out of scope).

## 5. Resources

| Resource | Source | Used for |
|---|---|---|
| **Food** | Farm (needs workers) | Each survivor eats 1 food at dawn. Surplus attracts newcomers. |
| **Wood** | Gatherers chop trees (1 wood per 0.625 s, carry 20); Lumber Yard boosts nearby chopping | Most buildings, walls, repairs |
| **Scrap** | Gatherers salvage scrap piles (1 scrap per 1.25 s, carry 20) | Turrets, Workshop, Radio Tower, ammo crafting |
| **Ammo** | Workshop: 1 scrap → 12 ammo per 5 s craft cycle, daytime only (needs a worker) | Guards and turrets consume 1 per shot |

Starting stock: **Food 30, Wood 60, Scrap 15, Ammo 40**. Starting jobs: **builder, wood gatherer, scrap gatherer, guard** (the guard holds night 1). There's no storage cap in v1. All numbers live in `game/data/*.json` and get tuned there.

## 6. Survivors

- Start with **4 survivors**. Each has a name, a sprite variant, HP 50, and a current job.
- **Jobs:** Idle, Gatherer (wood/scrap from nodes; auto-picks the nearest node of the chosen resource), Farmer, Builder, Crafter (Workshop), Guard.
- Survivors walk on the grid using pathfinding. They carry what they gather back to the Command Center or a Storage building.
- **At night**, non-guards go to Shelter or the Command Center and are safe inside unless it's destroyed. Guards stand on watchtowers or a guard post, or near the Command Center.
- **Food:** at dawn each survivor eats 1 food. If food is short, the survivors who don't eat become Hungry and work at 50% speed. After 2 hungry days in a row, a survivor leaves the colony.
- **Newcomers:** at dawn, if beds > population and food ≥ 2 × population, 1–2 newcomers arrive.
- **Beds:** the Command Center has 4. Each Shelter adds 4.

## 7. Buildings

Players place blueprints, and Builders construct them (build time in work-seconds). The cost is paid when the blueprint is placed. Cancelling refunds 100% before construction starts and 50% after.

| Building | Size | Cost | HP | Workers | Effect | Unlock |
|---|---|---|---|---|---|---|
| Command Center | 2×2 | – | 1000 | – | Drop-off point, 4 beds. **If it's destroyed, you lose.** | start |
| Wooden Wall | 1×1 | 5 wood | 200 | – | Blocks zombies | day 1 |
| Gate | 1×1 | 10 wood | 200 | – | Wall that survivors can pass through | day 1 |
| Shelter | 2×2 | 30 wood | 200 | – | +4 beds, night safety | day 1 |
| Farm | 2×2 | 20 wood | 200 | up to 2 | +8 food per farmer per day | day 1 |
| Storage | 2×2 | 25 wood | 150 | – | Extra drop-off point | day 2 |
| Watchtower | 1×1 | 25 wood, 5 scrap | 150 | 1 guard | Guard range +50%, guard is protected | day 2 |
| Workshop | 2×2 | 30 wood, 10 scrap | 150 | 1 | Crafts ammo (1 scrap → 12 ammo every 5 s) | day 2 |
| Lumber Yard | 2×2 | 30 wood | 150 | – | +50% chopping speed within 6 tiles | day 3 |
| Turret | 1×1 | 10 wood, 25 scrap | 200 | – | Auto-fires (uses ammo), range 6 tiles, 2 shots/s, 40 damage | day 4 |
| Reinforced Wall | 1×1 | 5 wood, 5 scrap | 400 | – | Upgrade from Wooden Wall | day 6 |
| **Radio Tower** | 2×2 | 150 wood, 120 scrap | 500 | – | Long build (150 work-s). Required to win. | day 8 |

**Combat:** guards fire 1 shot/s for 40 damage, range 5 tiles (7.5 on a watchtower); turrets fire 2 shots/s for 40 damage, range 6 tiles. Hits are certain, so a walker or runner takes 1 shot and a brute 5.

Builders repair damaged buildings during the day. A repair costs wood equal to 25% of the build cost, scaled by damage.

## 8. Zombies

| Type | HP | Speed (px/s) | Damage | Attack/s | Appears | Notes |
|---|---|---|---|---|---|---|
| Walker | 40 | 45 | 6 | 1.0 | night 1 | basic |
| Runner | 25 | 95 | 4 | 1.5 | night 4 | targets survivors first |
| Brute | 200 | 36 | 25 | 0.7 | night 11 | targets walls and buildings first; bigger sprite |

- **Targeting:** path to the Command Center. If the path is blocked by walls, attack the cheapest blocking structure. That means pathfinding treats structures as passable with a high cost, and zombies stop to attack whatever is in the way. Zombies attack any survivor within 1.5 tiles.
- They use one shared flow field or AStarGrid2D toward the Command Center. Recompute when buildings change. Don't run per-zombie A* every frame.
- **Performance target:** 250 zombies at 60 fps.

## 9. Waves

Waves are defined in `game/data/waves.json`. The baseline for night *n*:
- walkers = 4 + 3n
- runners = max(0, 2(n − 3))
- brutes = max(0, n − 10)
- spawn sides: nights 1–3 = 1 side, 4–9 = 2, 10–11 = 3, 12+ = 4
- Spawns trickle in over the first 35% of the minimum night (14 s).
- **Night 20 is the FINAL HORDE:** triple the counts (192 walkers, 102 runners, 30 brutes), all 4 sides, a red sky tint, and a special banner.

## 10. Win and lose

- **Win:** the Radio Tower is complete and you survive night 20. If the Radio Tower isn't done by night 20, the nights continue, getting harder each time. Rescue happens at the first dawn after the tower is done and night 20 or later has passed. A helicopter flies in, then the Victory screen shows stats.
- **Lose:**
  - The Command Center is destroyed, or the survivor count reaches 0. The Game Over screen shows stats and offers Restart / Main Menu.
- **Stats:** nights survived, zombies killed, survivors lost, buildings built, and time played.

## 11. Controls and UI

- **Camera:** WASD or arrow keys to pan, edge-pan, mouse wheel to zoom (0.5×–2×). The camera is clamped to the map.
- **Time:** Space pauses. 1, 2, and 3 set the game speed.
- **Build hotkeys (M8):** F1–F9 pick the build-bar buttons in order.
- **Build:** B or the build bar opens the build menu. Left-click places, right-click or Esc cancels. Shift+click places repeatedly, which is useful for walls. Drag to place a line of walls.
- **Selecting:** click a survivor or building to see an info panel. Survivors get a job dropdown, and buildings show HP and workers.
- **Survivor roster:** a panel (R) listing everyone, with quick job assignment.
- **Top bar:** Food / Wood / Scrap / Ammo with icons, Day N, time until nightfall (or "NIGHT – n zombies left"), and speed controls.
- **Feedback:** health bars on damaged entities, floating "+3 wood" popups, a screen-edge red flash when the Command Center is attacked.
- **Screens:** Main Menu (New Game, How to Play, Settings, Credits, Quit), Pause menu (Resume, Restart, Settings, Quit to Menu), Settings (master/SFX/music volume, fullscreen or windowed, default game speed 1×/2×/3× for new games, hints on/off; saved in `user://settings.cfg`), How to Play, Credits, Game Over, Victory, Dawn Report. Back or Esc on Settings, How to Play and Credits returns to the menu that opened them.
- **Tutorial hints:** short cards in the top-left corner teach the loop the first time it matters: welcome (day 1), build a farm, night is coming, ammo and the Workshop, hunger, and the Radio Tower unlock. Each shows at most once per game, closes on "Got it" or after 12 s, and never pauses the game. Hints are on by default and can be turned off in Settings, reachable from the main menu or the pause menu (saved in `user://settings.cfg`).

## 12. Art and audio

See `project/ART_GUIDE.md`. v1 shipped with Kenney top-down art (CC0), with AI-generated art filling gaps in that style. From M6 the art moves to Ittai Manero's 3/4-view pixel art (§16), and `ART_GUIDE.md` now describes that style. For audio, Kenney impact and interface sounds, plus CC0 ambience and music if found (credit everything in `CREDITS.md`).

## 13. Out of scope for v1

Save and load mid-run (added in M7 as dawn autosave, §17.1), multiplayer, tech trees beyond unlock-by-day (a small one added in M12, §23), morale/mood systems (added in M12, §22), scavenging expeditions off-map (added in M8 as scavenging runs, §18.2), weather (added in M10, §20.1), modding, controller support. These can become stretch tasks only after M5 ships.

## 14. Milestones

| M | Goal | Done when |
|---|---|---|
| M0 | Foundation | Art curated, data files, the build runs, tests pass |
| M1 | Map and building | You can pan around a generated map, see resources, and place buildings that cost resources. Day timer runs. |
| M2 | Colony | Survivors walk, gather, farm, build, eat, sleep. Newcomers arrive. |
| M3 | Siege | Nights happen. Zombies path, attack, and die. Walls, towers, and turrets work. You can lose. |
| M4 | Full game | 20 nights, wave scaling, Radio Tower, win, menus, Dawn Report, balanced by a simulation bot |
| M5 | Ship | Audio, art polish, tutorial hints, full-run pacing, Windows .exe build, final QA, README |
| M6 | Graphics overhaul (post-v1) | The whole game uses Ittai Manero's 3/4-view pixel art with animated survivors and zombies, a themed pixel UI, restyled menus with fades, an animated title scene, and Settings / How to Play / Credits screens. The Windows build is re-exported. |
| M7 | Come back to it, choose your siege (post-v1) | Continue from the last dawn, Easy/Normal/Hard, CC alarm and screen shake, build info card, night forecast. QA'd and re-exported as v1.2.0. |
| M8 | Beyond the walls (post-v1) | Spitter zombie from night 8, scavenging runs by day, build hotkeys F1–F9, balance pass with the bot, QA and v1.3.0 export. |
| M9 | Hold the line (post-v1) | Keep fighting past night 20 (endless), New Game seed reroll + seed in the pause menu, defender range preview, balance pass, QA and v1.4.0 export. |
| M10 | Storm season (post-v1) | Rain days and fog nights (seeded, forecast in the morning), an Idle-survivors button, personal records per difficulty, a weather balance pass, QA and v1.5.0 export. |
| M11 | Measured pressure (post-v1) | Endless-only wave damping, reload-day from the dawn autosave, balance pass v5 with the repeat harness and the forecast-aware bot, QA and v1.6.0 export. |
| M12 | Morale and research (post-v1, final, owner request R-11) | Survivors have morale that reacts to events and changes work speed and accuracy, with clear levers; a small 3-branch tech tree researched at a new building (Radio Tower win unchanged); spitter standoff fixed; balance pass v6, QA and v1.7.0 export. The last milestone. |

## 15. Change log

- 2026-10-10 (T-027 balance pass 1): guard and turret damage 10 → 40, Workshop 1 scrap → 10 ammo every 8 s (was 5 ammo every 10 s), farm 8 food per farmer (was 3), wood 1 per 1.25 s (was 1.5 s), scrap piles 25–45 (was 15–30), a guard among the starting jobs, brutes from night 11 (n − 10, was n − 7). Numbers and reasons in `project/decisions.md`.
- 2026-10-10 (plan): §11 adds tutorial hints (T-032) and the Hints toggle in the pause menu.
- 2026-10-11 (T-098 pacing): §1 target restated to about 40–45 min at 1x (was 30–40). Day 150 → 70 s, night minimum 45 → 40 s, spawns over 35% of the minimum night (was 60%), walker speed 40 → 45, brute 30 → 36, survivor speed 96 → 110, turret range 5 → 6. Production per day is kept by halving gather, craft and build times and doubling carry to 20. Numbers and reasons in `project/decisions.md`.
- 2026-10-11 (T-115 balance pass 2): brutes from night 10 (n − 9, was n − 10), brute HP 220 → 200 (5 shots, was 6), turret range 6 → 5, farm HP 100 → 200. Numbers and reasons in `project/decisions.md`.
- 2026-10-11 (T-128 balance pass 3): §9 final horde ×3 (was ×2), 4 spawn sides from night 12 (was 15), brutes from night 11 (n − 10, was n − 9); §8 brute row updated. Numbers and reasons in `project/decisions.md`.
- 2026-10-11 (T-136 balance pass 4): §5 and §7 Workshop craft cycle 4 → 5 s (1 scrap → 10 ammo). Trims the late ammo surplus by about 10%; the CC-damage target was not reachable with economy levers. Numbers and reasons in `project/decisions.md`.
- 2026-10-11 (plan 19:58): §17.4 adds the build info card (T-152).
- 2026-10-11 (plan): §16 adds night readability (owner request R-9) and decor + combat FX (T-107/T-140).
- 2026-10-10 (plan): §14 adds full-run pacing to M5 (owner request R-4) and an M6 graphics-overhaul row; §16 describes M6 (owner request R-5).
- 2026-10-11 (T-111): §11 Screens lists the new Settings, How to Play and Credits screens; the pause menu's inline volume and hint controls moved to Settings.
- 2026-10-11 (T-100): §12 now says v1 used Kenney art and points to §16 and the rewritten `ART_GUIDE.md` for the M6 pixel-art style. §16 is unchanged.
- 2026-10-11 (plan): §17 adds M7: Continue with autosave at dawn (save/load leaves the §13 out-of-scope list), Command Center alarm + screen shake, and Easy/Normal/Hard difficulty.
- 2026-10-12 (plan): §17.3 updated to T-147's measured result: difficulty changes wave size only (Easy ×0.85, Hard ×1.2). §17.5 adds the night forecast (T-162). §18 adds M8: Spitter zombie, scavenging runs and build hotkeys (scavenging leaves the §13 out-of-scope list). §14 adds M7 and M8 rows.
- 2026-10-12 (plan 04:29): §18.3 build hotkeys are F1–F9 (keys 1–3 already set the game speed). §18.2 runs return at nightfall, matching T-166 (the clock has only day and night).
- 2026-10-12 (T-169 M8 balance pass): §18.1 spitters from night 8 (floor((n − 5) / 3), was / 2), HP 60 → 40, acid 10 → 6 damage; §18.2 scavenging loot wood 10–20, scrap 5–15, food 0–8, ammo 0–20 (was 15–35, 10–25, 5–20, 0–30), risk unchanged; §14 M8 row says night 8. Seed-1337 run is 44:41.25 at 1x. Numbers and reasons in `project/decisions.md`.
- 2026-10-12 (plan): §14 adds the M9 row and §19 describes M9 "hold the line" (endless mode, seed reroll, defender range preview).
- 2026-10-12 (plan 10:02): §14 adds the M10 row and §20 describes M10 "storm season" (weather, idle-survivors button, personal records). Weather leaves the §13 out-of-scope list.
- 2026-10-12 (plan): §14 adds the M11 row and §21 describes M11 "measured pressure" (endless damping, reload-day, balance pass v5).
- 2026-10-12 (T-197 weather balance pass): §20.1 rain chance 20% → 15% (farms still +50%), fog chance 15% → 10% (still from night 5, range −1 tile, never on night 20 or twice in a row). About 1.3 fog nights and 3 rain days per run; rain adds about 24 food per run (8% of food made). Seed-1337 run wins at 45:09.5 at 1x (was a night-19 loss under 15% fog). Numbers and reasons in `project/decisions.md`.
- 2026-10-12 (T-207 balance pass v5): §5 and §7 Workshop 1 scrap → 12 ammo (was 10), §7/§8 turret range 5 → 6 tiles, §18.1 spitter acid range 3 → 2 tiles; `endless_wave_mult` stays 1.0. Seed-1337 run wins at 41:42 at 1x. Numbers and reasons in `project/decisions.md`.
- 2026-10-12 (plan 15:27): §14 adds the M12 row (owner request R-11: survivor morale and a tech tree, the final milestone). §22 and §23 are written by the M12 design task T-213 before any M12 code.
- 2026-10-12 (T-213 M12 design): §22 adds survivor morale (0-100 = baseline 50 + 19 active mood types; bands Inspired 75+ / Steady 40+ / Low 20+ / Breaking; work ×1.15/1.0/0.85/0.7, guard hit chance 100/100/85/70%, turrets never miss; Breaking refuses work, two Breaking dawns in a row leaves, at most one per dawn; levers Campfire, Feast, Day off; seeded combat RNG drawn only below Steady). §23 adds the tech tree (Field Lab 2×2 day 3, Researcher 10 RP/day, nine upgrades in Defense/Economy/Survivors at 20/35/50 RP, `state.tech.mult/bonus` lookups, T screen), exact config/save schemas, independent healing/bed hooks, and a responsive 12-button bar. §13 notes both. T-214..T-222 rewritten with file fences, tests and the merged T-223 midgame pressure target. Steady is today's game and the Radio Tower win is unchanged. Reasons in `project/decisions.md`.
- 2026-10-13 (T-220 balance pass v6): §7 Wooden Wall HP 150 → 200, §17.3 Hard hordes 20% → 10% bigger. Normal sensible majorities 5/5/0 (miss by one win, zero losses), Hard 1/1/8 → 6/0/4 (in the 4..7 band, all losses on night 20); Easy 5/5/0, do-nothing still loses on night 4 everywhere. Nights 8-12 still deal no CC damage on any seed (miss, see decisions); seed-1337 run survives/wins at ~40-41 min at 1x. Numbers and reasons in `project/decisions.md`.

## 16. Post-v1: M6 graphics overhaul (owner request R-5)

Planned for after v1 ships. Not part of v1.
- **Art:** pixel art from Ittai Manero's free "Zombie Apocalypse Tileset" (`asset_library/ittaimanero/`, credit in `CREDITS.md`, no redistribution of the raw pack). 16 px source drawn at 4× on the 64 px grid, nearest-neighbour filtering. The view becomes 3/4 top-down (roofs visible). Characters and zombies use 4-direction animated sprites (idle/walk/attack/hurt/death) instead of rotating. Walker, runner and brute map to pack zombies. Gaps (turret, radio tower, watchtower, guard post, survivor variants) are drawn by Codex to match. `project/ART_GUIDE.md` is rewritten first.
- **UI:** a pixel font (pack or OFL), 9-slice panels and buttons with hover/pressed states, and HUD icons in the same style, applied through one Godot Theme.
- **Menus:** themed main menu, pause menu, Dawn Report, Game Over and Victory, with short fade transitions. The main menu shows a live, scripted siege scene behind the buttons.
- **New screens:** **Settings** (master/SFX/music volume, fullscreen or windowed, default game speed 1×/2×/3×, saved in `user://settings.cfg`), **How to Play** (goal, controls, tips) and **Credits** (from `CREDITS.md`). All reachable from the main menu; Settings also from the pause menu.
- **Night readability (owner request R-9):** night keeps its blue mood but stays readable. The night tint is lighter, completed Command Center, Shelters, Watchtowers, Turrets and the Radio Tower cast warm light pools, and the Final Horde (night 20) is tinted clearly red. Zombies get a pale 1 px rim and glowing eyes at night, and their HP bars stay visible all night. By day nothing changes.
- **Decor and combat FX:** wrecked cars near the roads and small clusters of barrels, tires, signs, straw and bushes decorate empty grass. Decor is view-only: it never blocks movement or building and hides under buildings. Shots show pixel pistol (guards) and shotgun (turrets) flashes; hits spray blood; kills leave a corpse and a stain that fade away at dawn.

## 17. Post-v1: M7 "come back to it, choose your siege"

Goal: a 40–45 minute run you can stop and resume, a challenge level you choose, and physical feedback when the base
is hit. Planned 2026-10-11; tasks T-144 to T-150.

### 17.1 Continue (autosave at dawn)
- The game saves automatically at every dawn to `user://savegame.json` (one slot). There is no manual save.
- A save is a snapshot of the start of that day: map seed, day, resources, buildings (with HP, completion and
  blueprint progress), survivors (name, look, job, HP, hunger, tile), remaining resource nodes, stats, difficulty and
  which tutorial hints were seen. No zombies exist at dawn, so none are saved.
- Continuing starts that day from the beginning with the clock at full daylight. Survivors restart their jobs from
  where they stood (anyone inside a Shelter steps out next to it).
- The main menu shows **Continue (Day N)** above New Game when a valid save exists. Game Over and Victory delete it.
  A broken or old-version save is discarded without crashing. The pause menu notes "Progress is saved every dawn".

### 17.2 Command Center alarm and screen shake
- When the Command Center takes damage, the screen edges flash red and fade over about a second (at most every
  0.4 s). This fulfils the §11 feedback promise.
- Losing a building shakes the screen briefly (stronger for the Command Center); CC hits add a tiny shake. Shake is at
  most 6 px, whole pixels, and only moves the camera view, never the UI. Settings has a **Screen shake** toggle
  (on by default).

### 17.3 Difficulty
- New Game asks for **Easy**, **Normal** or **Hard** (the last choice is remembered). Normal is exactly the balanced
  v1.1 game. Easy has hordes 15% smaller; Hard has hordes 10% bigger (was 20% until the T-220 balance pass v6). Multipliers live in `balance.json`
  (`difficulty` block: wave size, zombie HP, starting resources, food eaten) and are tuned with the balance bot: on
  Hard the sensible bot should win about half of its 10 seeds and the CC should take damage on several. T-147's tuning
  found that only wave size works as a lever (walker HP has a hits-to-kill cliff), so HP, supplies and food stay 1.0
  on every level. Hard: 6 won / 1 survived / 3 lost, CC damaged on 5 seeds.
- The difficulty shows in the pause menu and on the Victory and Game Over screens, and is part of the save.

### 17.4 Build info card
- Hovering a build-bar button (or having a building selected for placement) shows a small card above the bar: the
  building's name, one plain sentence on what it does, its HP and size, workers or beds, and, when you can't afford
  it, exactly what is missing ("Need 5 more scrap"). Numbers come from the data files, so they stay right after
  balance passes. It replaces the tiny cost tooltip.

### 17.5 Night forecast
- During the day (and dusk), a slim line under the top bar says what tonight brings: "Tonight: 22 walkers · 4 runners
  · 2 sides". It counts each type after the difficulty multiplier, exactly as the spawner will spawn it, and names
  how many sides they come from (which sides is decided at nightfall). Night 20 reads "FINAL HORDE: …" in red. It
  hides at night. It lets players decide in the morning whether to build walls, turrets or economy.

## 18. Post-v1: M8 "beyond the walls"

Goal: give the day a new decision (send someone out for supplies, at a risk) and give the night a threat that walls
alone don't answer. Planned 2026-10-12; tasks T-163 to T-171. Starts after the v1.2.0 export (T-150), except the
Spitter art, which is asset-only.

### 18.1 Spitter zombie
- A fourth zombie type drawn from the pack's "Turret Zombie" (walk, damaged and vomit-shooting frames). It appears
  from **night 8**: spitters = max(0, floor((n − 5) / 3)) (night 8: 1, night 13: 2, night 19: 4), ×3 on the Final
  Horde (15), scaled by difficulty like the others.
- Stats (tuned by T-169's balance pass; range by T-207): HP 40, speed 40 px/s, acid 6 damage every 2.0 s, range
  **2 tiles**. It walks the shared flow field like a walker, but stops when a target is within 2 tiles and spits a
  slow acid glob (about 160 px/s) that always lands on the target tile and damages what stands there.
- Targets: turrets and watchtowers first (including guards posted on them), then any structure blocking its path,
  then the Command Center. It never targets survivors on the ground directly. It melees for 4 damage if something is
  adjacent.
- Why: walls and turret clusters currently solve every night. A spitter outranges nothing (turret range 6) but chips
  defences from behind the wall line, so guards and turret coverage matter, not just wall thickness.
- The night forecast counts spitters, and on the first morning whose night has spitters a one-shot tutorial hint
  explains them (T-179).

### 18.2 Scavenging runs
- In the **morning** (the first 40% of the day), select a survivor who isn't a guard and press **Send scavenging**
  in the info panel (or the roster). They walk to the nearest map edge, leave the map and are away for the day. One
  run at a time (two from day 10 on).
- They come back when night falls (the clock has no separate dusk phase) to the Command Center with loot rolled from `expeditions.json` with the
  game's seeded RNG: wood 10–20, scrap 5–15, food 0–8, ammo 0–20, scaled up 2% per day (tuned by T-169: a run is
  worth about one worker-day of gathering plus a little for the risk). 15% chance they bring a
  newcomer if a bed is free.
- Risk: the chance they come back hurt (half HP) is 10% + 1% per day (max 30%). The chance they don't come back at
  all is 2% + 0.5% per day (max 12%); it's reported in the Dawn Report and the toast.
- A toast on return: "Mara is back: +32 scrap, +12 food". The Dawn Report lists runs. Nobody is away at dawn, so
  saves don't change.
- Why: every day gets a choice: one fewer worker today for a bigger, riskier haul. It also gives scrap-starved runs a
  way out.

### 18.3 Build hotkeys
- Keys **F1–F9** pick the build-bar buttons in order (the info card and a small caption on each button show the key). Esc or right-click cancels as now. Not 1–9: keys 1, 2 and 3 already set the game speed (§11).

## 19. Post-v1: M9 "hold the line"

Goal: reward a won run, remove two blind spots, and keep pressure fair.
Planned 2026-10-12; tasks T-186 to T-191. Starts after the v1.3.0 export
(T-171).

### 19.1 Endless mode
- The Victory screen offers **Keep fighting** next to Restart / Main Menu.
  It resumes the same colony: nights 21+ spawn from the base wave formula
  (no more ×3 Final Hordes), the win never fires twice, and a later loss
  shows Game Over with full stats.
- The win still deletes the save when the panel shows; the next dawn
  autosave includes the endless flag, so Continue resumes endless. Past
  night 20 the forecast shows real counts (no FINAL HORDE label) and the
  Dawn Report objective reads "Survive as long as you can".

### 19.2 Seed reroll
- New Game shows the rolled **Seed: NNNNN** with a **Reroll** button next
  to the difficulty buttons; starting uses the shown seed. The pause menu
  shows "Seed NNNNN · Easy/Normal/Hard" read-only. Restart still keeps the
  run seed. Menu rerolls never consume the game RNG stream.

### 19.3 Defender range preview
- A turret or watchtower ghost in BuildMode draws a ground ring of its
  data range (green = valid placement, red = not). Selecting a complete
  turret, watchtower or guard shows the same ring plus an info-panel line
  ("Range: 6 tiles" / "Range: 7.5 tiles"). Rings are thin outlines that
  never block clicks or hide zombies at night.

## 20. Post-v1: M10 "storm season"

Goal: make days and nights differ from each other, so the morning plan
changes with the sky; stop idle survivors from wasting days; give
replays (and endless) a score to beat. Planned 2026-10-12; tasks T-193
to T-199. Starts after the v1.4.0 export (T-191).

### 20.1 Weather
- Each day and each night gets one weather roll: day = Clear or **Rain**,
  night = Clear or **Fog**. Rolls come from their own RNG seeded from the
  map seed and the day number, so they never consume the game's RNG
  stream, are the same on Restart and Continue, and need nothing new in
  the save.
- **Rain (day):** farms make +50% food that day. Survivors work normally.
  From day 2, chance 15%. Rain shows as light pixel streaks over the
  map (never over the UI).
- **Fog (night):** guard, watchtower and turret ranges drop by 1 tile
  (turret 5 → 4, guard 5 → 4, tower guard 7.5 → 6.5). From night 5,
  chance 10%; never on night 20 (the Final Horde) and never two fog
  nights in a row. Fog shows as slow drifting pale patches, light enough
  that zombies (rim, eyes, HP bars from §16) stay readable.
- The morning forecast names it, so players can answer it by day:
  "Tonight: 22 walkers · 4 runners · 2 sides · Fog: range −1". A rain day
  shows a small "Rain: farms +50%" tag in the top bar. Range rings and
  the info-panel range line use the effective range (fogged at night;
  by day a fog forecast adds "4 in fog tonight").
- All chances and effects live in `game/data/weather.json` and are tuned
  by the balance bot (T-197). Endless nights roll like any other night.

### 20.2 Idle survivors button
- The top bar shows **Idle: N** when N survivors have the Idle job (by
  day; hidden when N is 0 and at night). Clicking it, or pressing **I**,
  selects the next idle survivor in roster order and centres the camera
  on them, cycling on each press.

### 20.3 Personal records
- Saved per difficulty in `user://records.cfg`: best nights survived
  (completed nights, endless included), wins, and fastest win (time
  played). Updated when Victory or Game Over shows.
- Victory and Game Over show "New record!" lines when one is beaten. The
  main menu shows one small line, "Best: Easy 12 · Normal 23 · Hard 9
  nights", once any record exists. Records never affect gameplay.

## 21. Post-v1: M11 "measured pressure"

Goal: turn the new measurement tools (repeat harness, forecast-aware
bot) into a trustworthy balance signal, add the endless lever T-189
asked for, and let players undo a disastrous day. Planned 2026-10-12;
tasks T-206 to T-210. Starts after the v1.5.0 export (T-199); the
harness (T-203) and bot (T-204) halves already landed.

### 21.1 Endless wave damping

- `waves.json` gains one key (e.g. `endless_wave_mult`, default 1.0)
  that scales spawn counts for nights 21 and later only. Nights 1-20
  are byte-identical with it at any value.
- Why: nights 21+ share the base formula, so no data lever can tune
  endless without retuning the whole campaign (T-189). This key is
  that lever; the balance pass sets it.

### 21.2 Reload day

- The pause menu offers **Reload day** whenever a valid dawn autosave
  exists (always, except before the first dawn). It loads
  `user://savegame.json` exactly like Continue: same seed, day,
  resources and difficulty, clock at full daylight.
- A broken or old-version save hides the button instead of crashing.
  It never touches endless flags or records beyond what Continue
  already does.

### 21.3 Balance pass v5

- Data only, tuned with `--repeat=K` (K >= 3) win-rate majorities per
  seed and the v3.2 forecast-aware bot. Repairs the T-204 Normal
  regression and sets the endless key from real post-20 bot runs.

## 22. Post-v1: M12 survivor morale (owner request R-11)

Goal: survivors stop being interchangeable workers. How you treat them
(beds, food, losses, a fire to sit at) shows in how fast they work and
how well guards shoot, and a colony that is ground down starts to lose
people. Planned 2026-10-12 (design T-213); sim T-215, UI T-217. All
numbers live in `game/data/morale.json` (§22.9) and the Campfire entry
in `buildings.json`; the balance pass (T-220) tunes them there.

### 22.1 The number and its bands

- Every survivor has **morale**, a whole number **0-100**, shown with a
  mood icon. It is computed, not accumulated:
  **morale = clamp(baseline + sum of active mood values, 0, 100)**
  (baseline defaults to 50).
  A *mood* is a named modifier ("Slept in a bed +5", "Mara died -12")
  with a value and a lifetime in dawns (§22.2). Morale is recomputed
  whenever a mood is added or removed, so it moves on events and at
  dawn, and it drifts back towards 50 as moods expire. This replaces a
  per-day cap: a day can only stack the moods listed below, and
  repeatable bad news is capped by stack limits (deaths 2, departures 2).
- **Bands** (lower bound inclusive) and their effects:

| Band | Morale | Work speed | Guard hit chance | Icon (T-224) |
|---|---|---|---|---|
| **Inspired** | 75-100 | ×1.15 | 100% | `game/assets/pixel/ui/icon_mood_inspired.png` |
| **Steady** | 40-74 | ×1.00 | 100% | `game/assets/pixel/ui/icon_mood_steady.png` |
| **Low** | 20-39 | ×0.85 | 85% | `game/assets/pixel/ui/icon_mood_low.png` |
| **Breaking** | 0-19 | ×0.70 | 70% | `game/assets/pixel/ui/icon_mood_breaking.png` |

- **Steady is exactly today's game** (work ×1.0, every hit lands), so a
  colony that stays Steady plays the T-207-balanced numbers. With no
  levers, a fed, bedded, sheltered colony after an ordinary night sits
  at 57 (Steady); one death drops it to 45 (still Steady); hunger on
  top of a death drops it to Low. Night moods add their own modifiers.
- **Start values.** Founders start with the mood *Fresh start* (+10,
  2 dawns), so 60. Newcomers (dawn or scavenging) arrive with *Found a
  safe place* (+10, 2 dawns), so 60. A survivor restored from a save
  without morale data has no moods, so 50.

### 22.2 Moods

Lifetimes count dawns: a mood with **days N** is removed at the N-th
dawn after it was added (a 3-day death mood added on night 5 is gone at
dawn 8). **Dawn moods** (days 1) are rebuilt at every dawn from the
colony's state. **Stack** is how many moods with the same id a survivor
can hold; adding one more replaces the oldest (stack 1 = refresh the
lifetime and value).

| id | Player text | Value | Days | Stack | Who gets it, and when |
|---|---|---|---|---|---|
| `bed` | Slept in a bed | +5 | 1 | 1 | Dawn: non-duty residents who have a bed (§22.3) |
| `no_bed` | No bed | -10 | 1 | 1 | Dawn: non-duty residents with no bed |
| `sheltered` | Safe indoors | +2 | 1 | 1 | Dawn: residents who were actually sheltered at the end of the night |
| `hungry` | Hungry | -15 | 1 | 1 | Dawn: survivors who did not eat this dawn (§6) |
| `hurt` | Badly hurt | -8 | 1 | 1 | Dawn: HP below half of max HP (after First Aid, §23.3) |
| `campfire` | Warm campfire | +6 | 1 | 1 | Dawn: up to 6 survivors per complete Campfire (§22.5) |
| `quiet_night` | Quiet night | +4 | 1 | 1 | Dawn: surviving residents, if last night nobody died (including scavenging), no building was destroyed and the CC took no damage |
| `rough_night` | Rough night | -6 | 1 | 1 | Dawn: surviving residents, if last night a building was destroyed or the CC took damage |
| `fresh_start` | Fresh start | +10 | 2 | 1 | Founders at game start |
| `new_home` | Found a safe place | +10 | 2 | 1 | A newcomer, on arrival |
| `newcomers` | New faces | +4 | 2 | 1 | Everyone already in the colony when a newcomer arrives |
| `death` | {name} died | -12 | 3 | 2 | Everyone else, when a survivor is killed or lost on a scavenging run |
| `left` | {name} left | -6 | 2 | 2 | Everyone else, when a survivor leaves (hunger or morale) |
| `scavenged` | Back from a run | +8 | 2 | 1 | A scavenger who returns unhurt (§18.2) |
| `feast` | Feast | +10 | 3 | 1 | Everyone, when the player holds a Feast (§22.5) |
| `day_off` | Day off | +12 | 2 | 1 | The survivor, at the dawn after a Day off (§22.5) |
| `radio_tower` | The Radio Tower is up | +10 | 5 | 1 | Everyone, when the Radio Tower completes |
| `rescued` | Rescue came | +20 | 5 | 1 | Everyone, when the win fires (matters in endless) |
| `still_standing` | Still standing | +8 | 3 | 1 | Everyone, endless only: the dawn after nights 25, 30, 35, ... |

- Guards on night duty get neither `bed` nor `no_bed` (they were on
  watch). Nobody is away scavenging at dawn (§18.2). `newcomers` is
  applied to the existing residents immediately before each arrival;
  stack 1 refreshes it when two arrive. Cancelled/outbound scavenging
  runs give no `scavenged` mood. A loss is a `death`, never also `left`.
- Mood arrays are ordered oldest to newest. Refreshing/replacing
  appends at the end, including on the same tick. Per-id stack limits
  are also the per-day caps: e.g. three deaths leave exactly two -12
  moods (-24), two Campfires never exceed one +6 mood, a Feast can
  add only one +10 mood. `bed`/`no_bed` are mutually exclusive.
  Changes outside dawn affect band effects immediately but do not
  change refusal or `breaking_days` until the next dawn. No extra
  ambient drift, injury-on-hit delta, or per-day accumulator exists.
- `{name}` is filled in when the mood is added and stored with it, so
  the text survives saves and the survivor leaving the roster.

### 22.3 Dawn order

Morale has two steps per dawn, both called from `GameState._on_dawn`:

- **`Morale.begin_dawn(state)`**, first thing in `_on_dawn`, before
  `DawnRules.process`: every mood's remaining days drops by 1 and moods
  at 0 are removed; every survivor's `refusing` and `day_off`
  flags are cleared (a survivor who had a day off is remembered as
  `had_day_off` for step 3 below). Before clearing anything, snapshot
  the resident uids, actual `sheltered` flags and night-duty guards
  (`job == GUARD` and neither refusing nor day off). Use this snapshot
  even if jobs change or newcomers arrive later in this dawn. Event
  moods added later in the same dawn (newcomers,
  deaths) therefore keep their full lifetime.
- `DawnRules.process` runs unchanged (eat, hunger leaving, newcomers;
  newcomer moods are added as they arrive).
- **`Morale.end_dawn(state, report)`**, after the night-log summary is
  merged into the report and before `_check_lose`:
  1. `left` mood for everyone else, per name in `report["left"]`
     (hunger leavers).
  2. **First Aid** has already healed residents once in the independent
     `TechTree.apply_dawn_heal(state)` hook after `DawnRules.process`
     and before this call (§23.4). Never heal twice; without tech the
     hook is absent and healing is zero.
  3. Dawn moods. *Beds:* take `state.buildings.total_beds()`, sort the
     surviving snapshot residents who were not on night duty by uid;
     the first *beds* get `bed`, the rest `no_bed`. This is an abstract
     bed entitlement, separate from physical shelter occupancy. Add
     `sheltered` only from the captured actual shelter flag. Newcomers
     at this dawn receive neither sleep nor last-night moods; they can
     receive hunger/hurt/campfire modifiers. Refusing/day-off guards
     count as non-duty residents for bed allocation. *Hunger:* `hungry`
     for `hungry_days > 0`. *Hurt:*
     `hurt` for `hp * 2 < max_hp`. *Campfires:* each complete Campfire,
     in uid order, gives `campfire` to the next 6 survivors (uid order,
     guards included) who don't have it yet. *Night:* `rough_night` if
     the summary has `cc_damage > 0` or any `buildings_destroyed`; else
     `quiet_night` if `survivors_killed` is empty and no scavenger was
     lost in `report.scavenging`; else neither. Night modifiers apply
     only to surviving snapshot residents; `rough_night` wins over
     `quiet_night`, and the two are mutually exclusive. *Day
     off:* `day_off` for survivors who took one yesterday.
  4. Add the endless milestone mood if applicable (night > 20 and
     night modulo `endless_milestone_every` is zero, while endless);
     recompute every survivor's morale. Clear `had_day_off` afterwards.
  5. **Breaking check** (§22.4).
  6. Write `report["morale"]` (§22.7) and append morale leavers to
     `report["left"]`. `_check_lose` then `_check_win` retain today's
     order; refresh the band counts after any `rescued` mood and before
     `dawn_processed` emits and the autosave runs.

### 22.4 Breaking: refusing work and leaving

- At step 5, every survivor in **Breaking** adds 1 to
  `breaking_days`; everyone else resets it to 0.
- A survivor with `breaking_days >= 1` **refuses work for the day**
  (`refusing = true` until the next dawn): they keep their job but do
  nothing (by day they stand idle where they are; at night they shelter
  like a non-guard, so a Breaking guard leaves the wall). They cannot be
  sent scavenging or given a Day off. Changing their job is allowed and
  takes effect when the refusal ends. The info panel and roster show
  "Refusing work".
- A survivor with `breaking_days >= 2` (Breaking at two dawns in a row)
  **leaves the colony** instead, like the hunger rule: removed, counted
  in `survivors_left`, "Left (lost heart): Bob" in the Dawn Report, and
  everyone else gets `left` and is recomputed immediately. Determine
  the candidates once before removing anyone; this new departure mood
  cannot trigger a second Breaking check that dawn. **At most one
  survivor leaves for morale
  per dawn** (lowest morale, then lowest uid); the others refuse work
  today and leave at the next dawn if still Breaking. One disaster
  cannot empty the colony in a single dawn.
- Losing the last survivor this way is the normal §10 loss.

### 22.5 Player levers

1. **Campfire** (new building): 1×1, **15 wood**, HP 80, build 5
   work-s, no workers, no beds, **unlocks day 2**. Each complete
   Campfire gives `campfire` (+6) at dawn to up to 6 survivors.
   Zombies can destroy it like any building. Sprites from T-224:
   `game/assets/pixel/buildings/campfire.png` (blueprint ghost and
   build-bar icon) and `game/assets/pixel/buildings/campfire_lit.png`
   (4-frame 16×16 flicker loop, exactly 6 fps, once complete). It casts
   a night light with the existing warm color/energy curve, at 0.75
   of a Shelter light's scale; removed when destroyed.
2. **Feast** (Command Center info panel button "Hold a feast"): by day
   only, costs **2 food per survivor** (all at once), gives everyone
   `feast` (+10, 3 dawns). The next feast is allowed **3 days later**
   (feast on day 5, next on day 8). When unavailable the button is
   disabled with the first applicable reason in this order: "Game over",
   "Night", "Next feast: day N", "Need N food" (N is the missing food,
   not the total cost). Away/scavenging survivors count in the cost
   and receive the mood too. The command is atomic, rejected commands
   spend nothing, and `last_feast_day == 0` means no cooldown.
3. **Day off** (survivor info panel and roster button, next to Send
   scavenging): in the **morning** only (first 40% of the day, as
   §18.2), not for a survivor who is away, scavenging or refusing. The
   survivor stops working until dawn exactly like a refusal (a guard
   leaves the post and shelters at night) and at the next dawn gets
   `day_off` (+12, 2 dawns). It costs one worker-day. Allowed only
   while `elapsed < day_length * day_off_morning_fraction`; at exactly
   28 s it is too late. Block reasons in order: "Game over", "Missing
   survivor", "Not morning", "Away", "Refusing work", "Already off".
   No daily colony-wide limit; no cancellation. Job changes and move
   orders cannot bypass refusal/day off. When either starts, leave any
   guard post, clear path/work_uid/work_acc, set activity Idle, retain
   carried cargo and the selected job; normal sheltering handles cargo.
   These flags last through the following night and clear at dawn.
4. Levers the player already has: beds (Shelters; `no_bed` is -10),
   food (Farms; `hungry` is -15), good defences (quiet nights),
   scavenging (`scavenged`), finishing the Radio Tower, and the
   Survivors branch of the tech tree (§23.3: Camp Songs, First Aid,
   Bunk Beds).

A typical good colony: 50 + bed 5 + campfire 6 + quiet night 4 = 65
(Steady; 67 if actually sheltered). Inspired needs an active choice on
top: a Feast, a Day off,
the Radio Tower, or stacked positive event moods. Camp Songs alone
raises that example to 70 including Safe indoors (+2), still Steady;
a Feast raises it to 80 (Inspired).

### 22.6 Effects in the sim

- **Work speed:** one multiplier, `Morale.work_mult(state, s)`, the
  band's `work_mult`. `Jobs.tick` multiplies the job delta by it on top
  of Hungry's ×0.5 (Hungry + Low = ×0.425) for **Builder (build and
  repair), Gatherer (harvest), Farmer, Crafter and Researcher** (§23).
  It does not change walking speed, sheltering, or guard fire rate.
  Refusing or day-off survivors get no job tick at all by day.
- **Guard hit chance:** this extends §7 ("hits are certain"), which
  stays true for Steady and Inspired guards and for every turret. Each
  guard shot (ground post or watchtower) spends 1 ammo and picks its
  target exactly as today; then, if the guard's band hit chance is below
  1.0, it draws `state.combat_rng.randf()` and **misses** when the draw
  is >= the chance. A miss emits `shot_fired` (muzzle flash and tracer
  to the target) but never calls `damage_zombie` (no damage, no blood).
  It returns the target, so the shot's cooldown and facing advance;
  no target or no ammo produces no shot and consumes no RNG draw.
  **Turrets never miss:** they have no crew (§7), so morale reaches them
  only through the crafter's ammo speed.
- **Determinism.** `state.combat_rng` is a `RandomNumberGenerator` owned
  by `GameState` and re-seeded at every nightfall with
  `hash([map_seed, day, "combat"])` (the weather pattern, §20.1). It is
  drawn **only** when a guard below 100% fires, in the existing
  deterministic guard tick order, so a Steady or Inspired colony makes
  zero draws and replays exactly as before. It never touches
  `state.rng`, needs nothing in the save (every night starts from a
  fresh seed), and is identical on Restart, Continue and Reload day.

### 22.7 UI

- **Roster (R):** a mood column with the band icon (16 px source at 2×)
  and the number ("62"); refusing survivors show "Refusing" in the
  status column. Must fit 1280×720 next to the existing columns.
- **Info panel (survivor):** "Morale 62 · Steady" with a thin bar
  (theme bar textures, 0-100), and under it the **top two moods** by
  absolute value (ties: newest first), e.g. "Mara died -12 · Slept in
  a bed +5". A **Day off** button beside Send scavenging, its disabled
  reason as tooltip.
- **Info panel (Command Center):** a **Hold a feast (-12 food)** button
  with its disabled reason.
- **Dawn Report:** one line "Morale: 3 Steady · 1 Low" (count per band,
  best first, empty bands omitted), plus "Refusing work: Bob" and "Left
  (lost heart): Eve" when they apply. `report["morale"]` =
  `{"bands": {"inspired": int, "steady": int, "low": int, "breaking":
  int}, "refusing": [names], "left_morale": [names]}`.
- **Tutorial hint** `morale` (one-shot, §11 rules): the first day any
  survivor is Low or Breaking: "Morale is slipping. Low and Breaking
  survivors work slower and guards miss shots. Build a Campfire, keep
  beds and food up, or hold a Feast at the Command Center."
- **How to Play:** one paragraph: "Morale. Each survivor's mood (0-100)
  sets how fast they work and how well guards shoot. Beds, food,
  campfires, feasts, days off and quiet nights help; deaths, hunger and
  rough nights hurt. A Breaking survivor refuses to work, and two
  Breaking mornings in a row means they leave."
- **Toasts** (reuse the scavenging toast): "Feast! Everyone +10 morale",
  "Bob refuses to work today". Format the Feast value from the mood
  config, and emit only on a successful command; refusal toast once
  per survivor per dawn.

### 22.8 Save

Optional keys; `SaveGame.VERSION` stays 1. A save without them loads
with defaults (no moods = 50, `breaking_days` 0, not refusing, no feast
held). Per survivor entry: `"moods": [{"id": String, "label": String,
"value": int, "days": int}]`, `"breaking_days": int`, `"refusing":
bool`. Top level: `"morale": {"last_feast_day": int}` (0 = never). A
pending Day off is never saved (the save is taken after dawn, when it
has already become the `day_off` mood). `_validate` checks optional
types and ranges only when keys are present, per §23.8.

### 22.9 `game/data/morale.json`

```json
{
  "baseline": 50,
  "bands": [
    {"id": "inspired", "name": "Inspired", "min": 75, "work_mult": 1.15, "hit_chance": 1.0},
    {"id": "steady",   "name": "Steady",   "min": 40, "work_mult": 1.0,  "hit_chance": 1.0},
    {"id": "low",      "name": "Low",      "min": 20, "work_mult": 0.85, "hit_chance": 0.85},
    {"id": "breaking", "name": "Breaking", "min": 0,  "work_mult": 0.7,  "hit_chance": 0.7}
  ],
  "moods": {
    "bed":   {"label": "Slept in a bed", "value": 5,   "days": 1, "stack": 1},
    "death": {"label": "{name} died",    "value": -12, "days": 3, "stack": 2}
  },
  "campfire_slots": 6,
  "feast": {"food_per_survivor": 2, "cooldown_days": 3},
  "day_off_morning_fraction": 0.4,
  "breaking": {"leave_after_dawns": 2, "max_leavers_per_dawn": 1},
  "endless_milestone_every": 5
}
```

(`moods` holds all 19 ids of the §22.2 table with its numbers; two are
shown.)

| Key | Type | Shipped value | Validation (`GameData._validate_morale`) |
|---|---|---|---|
| `baseline` | int | 50 | 0-100 |
| `bands` | array of 4 dicts | as above | ids exactly inspired, steady, low, breaking in that order; `min` ints strictly descending, last is 0, all 0-100; `name` non-empty string; `work_mult` > 0; `hit_chance` in (0, 1]; **steady has work_mult 1.0 and hit_chance 1.0** |
| `moods` | dict id -> dict | §22.2 table | every §22.2 id present; `label` non-empty string (may contain `{name}`); `value` int; `days` int >= 1; `stack` int >= 1 |
| `campfire_slots` | int | 6 | >= 1 |
| `feast.food_per_survivor` | int | 2 | >= 0 |
| `feast.cooldown_days` | int | 3 | >= 1 |
| `day_off_morning_fraction` | number | 0.4 | (0, 1] |
| `breaking.leave_after_dawns` | int | 2 | >= 2 |
| `breaking.max_leavers_per_dawn` | int | 1 | >= 1 |
| `endless_milestone_every` | int | 5 | >= 1 |

A missing or invalid `morale.json` fails `load_from_dir` like the other
files, and `_validate_morale` also requires a `campfire` entry in
`buildings.json`: `"sprite": "campfire"`, `"name": "Campfire"`,
`"blurb": "Cheers up to 6 survivors every morning."`, size [1, 1], cost
15 wood 0 scrap, hp 80, workers 0, unlock_day 2, build_time 5, beds 0.

## 23. Post-v1: M12 tech tree (owner request R-11)

Goal: a second, slower currency that turns a stable colony into a
chosen specialisation: harder defences, a richer economy, or happier
people. Small on purpose: one building, one job, nine upgrades in three
short chains, one research at a time. It **extends unlock-by-day**:
every §7 building keeps its unlock day, and **the Radio Tower and the
win condition (§10) never depend on research**. Planned 2026-10-12
(design T-213); sim T-216, UI T-218. Numbers live in
`game/data/tech.json` (§23.6) and the Field Lab entry in
`buildings.json`.

**Shared-hook merge contract.** T-215 and T-216 retain separate load,
validation and optional-save sections, without a version bump. The
second sim task to merge wires `campfire_morale` in Morale if the other
class is present; the first never references a missing class/property.
T-216 owns the independent heal hook and BuildingStore/ShelterRules bed
lookup, so those work even before morale merges. Both tasks test an old
save with neither optional key, and their own key without the other.

### 23.1 Field Lab and the Researcher job

- **Field Lab:** 2×2, **40 wood + 15 scrap**, HP 150, build **20
  work-s**, **2 workers** (Researchers), no beds, **unlocks day 3**,
  **at most one per colony** (`"max_count": 1`; a second placement is
  rejected with "Only one Field Lab"). Sprite
  `game/assets/pixel/buildings/field_lab.png` (T-224, 32×32 native, same
  box as `shelter.png`). Blurb: "Researchers earn research points by
  day." It casts a warm light pool at night like the Shelter.
- **Researcher** is a new job (it extends §6's job list;
  `Survivor.Job` appends `RESEARCHER`, saved as `"researcher"`, job
  dropdown entry "Researcher" after Guard). A Researcher walks to the
  Field Lab and works by day exactly like a Farmer at a Farm (activity
  `RESEARCHING`, same slot and retry rules, same night sheltering).
- **Research points (RP):** each working Researcher makes **10 RP per
  full day** (1 RP per 7 s at the 70 s day), continuously by day, scaled
  by work speed (Hungry ×0.5, morale band). RP are fractional inside the
  sim and shown rounded down. Icon `game/assets/pixel/ui/icon_research.png`
  (T-224).

### 23.2 Choosing and paying for research

- One **active research** at a time. The player picks any *available*
  upgrade (all prerequisites done, not done itself) on the tech screen.
  RP flow into it until its progress reaches its cost; then it is
  **done** at once, its effect applies immediately, a toast says
  "Research done: Spotters", and nothing is active until the player
  picks again.
- **Switching** is free: progress is kept per upgrade, so going back
  later resumes it.
- Selecting is allowed by day or night, with or without a Lab, including
  while paused via a sim command (the UI respects modal blocking).
  `TechTree.choose(id) -> bool` rejects unknown/locked/done ids or game
  over, spends nothing on rejection, and reselecting the active id is a
  no-op. `choose("")` pauses research and banks future RP; the UI has a
  "Pause research" button. Changing selection preserves every partial
  progress entry; at most one id is active.
- RP made while nothing is active go into a **bank**. Picking an
  upgrade pours the bank into it at once (up to its remaining cost; the
  rest stays banked). Overflow from a finished research is banked too.
  No RP are ever lost.
- Research costs nothing else (no wood, scrap or food).
- Destroying the Lab interrupts its workers via existing ProductionJob
  invalid-building logic; bank, progress, selection and done effects
  persist. A replacement can be built after destruction/cancellation.
  `max_count` includes completed buildings and blueprints; Placement
  adds `LIMIT_REACHED` (text "Only one Field Lab") without changing the
  numeric values of existing results.
- Pace: one Researcher from day 4 makes about 160 RP by night 20 (about
  five upgrades); two make about 320, enough for all nine (315 RP)
  around night 20. Nothing in the tree is needed to win.

### 23.3 Upgrades

Three branches, three tiers each; each tier needs the tier above it in
the same branch. Costs: tier 1 **20 RP**, tier 2 **35 RP**, tier 3
**50 RP** (315 in total).

| id | Branch | Tier | Name | Cost | Requires | Effect key | Op | Value | Player text |
|---|---|---|---|---|---|---|---|---|---|
| `spotters` | Defense | 1 | Spotters | 20 | - | `guard_range_tiles` | add | 1.0 | Guards see 1 tile further (5 -> 6, 7.5 -> 9 on a watchtower). |
| `oiled_turrets` | Defense | 2 | Oiled Turrets | 35 | spotters | `turret_fire_interval` | mult | 0.8 | Turrets fire 25% faster. |
| `reinforced_frames` | Defense | 3 | Reinforced Frames | 50 | oiled_turrets | `structure_damage_taken` | mult | 0.75 | All buildings take 25% less damage from zombies. |
| `better_tools` | Economy | 1 | Better Tools | 20 | - | `gather_time` | mult | 0.8 | Gatherers chop and salvage 25% faster. |
| `crop_rotation` | Economy | 2 | Crop Rotation | 35 | better_tools | `farm_food` | mult | 1.25 | Farms grow 25% more food (8 -> 10 per farmer). |
| `ammo_press` | Economy | 3 | Ammo Press | 50 | crop_rotation | `ammo_per_scrap` | add | 3 | The Workshop makes 15 ammo per scrap instead of 12. |
| `camp_songs` | Survivors | 1 | Camp Songs | 20 | - | `campfire_morale` | mult | 1.5 | Campfires give +9 morale instead of +6. |
| `first_aid` | Survivors | 2 | First Aid | 35 | camp_songs | `dawn_heal` | add | 10 | Every survivor heals 10 HP each dawn. |
| `bunk_beds` | Survivors | 3 | Bunk Beds | 50 | first_aid | `shelter_beds` | add | 2 | Each Shelter sleeps 6 instead of 4. |

### 23.4 How effects apply

- One lookup on the state: `state.tech` is a `TechTree` (pure sim,
  `game/scripts/sim/tech_tree.gd`). `state.tech.mult(key) -> float` is
  the product of the values of every done upgrade with that key and op
  `mult` (1.0 if none); `state.tech.bonus(key) -> float` is the sum for
  op `add` (0.0 if none). Call sites never copy data values; each reads
  the lookup when it runs, so an effect applies the moment research
  finishes and a game with no research behaves exactly as today.
  Dawn effects (Camp Songs/First Aid) sample at the next dawn; finishing
  research does not retroactively rewrite existing mood values or heal.
- One call site per key:

| Key | Where | Rule |
|---|---|---|
| `guard_range_tiles` | `GuardJob.effective_range_px` | (guard_range_tiles + bonus) × tower mult, then the fog delta; range rings and the info-panel range line use this same function |
| `turret_fire_interval` | `Combat.tick_turrets` | interval × mult |
| `structure_damage_taken` | `GameState.damage_building` | amount = max(1, round(amount × mult)); every caller is zombie damage (melee and acid), CC included |
| `gather_time` | `GathererJob.tick` | gather_time_<kind> × mult |
| `farm_food` | `ProductionJob.tick` | food_per_farmer × mult (stacks with rain) |
| `ammo_per_scrap` | `ProductionJob.tick` | ammo_per_scrap + int(bonus) |
| `campfire_morale` | `Morale.end_dawn` step 3 | round(campfire mood value × mult) |
| `dawn_heal` | `TechTree.apply_dawn_heal` after DawnRules, before morale/night moods | hp = min(max_hp, hp + int(bonus)), once per dawn, newcomers included |
| `shelter_beds` | `BuildingStore.beds_for(b)` | base beds + int(bonus) per complete Shelter; total_beds and ShelterRules.pick_shelter use this same lookup (GameState gives BuildingStore its tech reference); CC remains 4 |

- RP production uses `sim_dt * rp_per_researcher_per_day / day_length`
  after Hungry and morale, only when adjacent to a complete Lab, in
  ProductionJob slot rules. Refusing/day-off/away workers hold no
  slots. `TechTree.add_points(amount)` rejects negative/nonfinite
  input; exact completion uses a 0.000001 RP comparison tolerance,
  clamps progress to cost, appends the id once, clears active and
  banks overflow. Earlier effects apply to later job ticks in the
  existing uid order; completed research never auto-selects the next.
  No new RNG draws. Every effect survives losing/rebuilding the Lab.
- Effective guard ranges clamp to at least 1 tile after fog; Spotters
  yields 6/9 clear and 5/8 fog (ground/tower). Oiled Turrets changes
  0.5 s to 0.4 s; damage stays 40. Better Tools gives 0.5 s wood and
  1.0 s scrap, with existing Lumber Yard speed applied separately.
  Crop Rotation with rain yields 15 food per full Steady worker-day.
  Reinforced Frames rounds each positive hit separately with roundi
  (6 acid -> 5 damage), minimum 1; zero damage remains zero. No HP,
  repair cost or survivor damage change. First Aid never revives dead
  survivors and does not retroactively undo a hunger departure.
- Build info cards and info panels that print these numbers (Workshop
  ammo per scrap, Farm food, Shelter beds, ranges) print the effective
  value.

### 23.5 Tech-tree screen and HUD

- **Open:** hotkey **T** (new input action `tech_tree`, physical key T)
  or a HUD button with the research icon. Esc, T or the close button
  closes it. Blocked while the pause menu is open (like the roster). The
  game keeps running underneath, like the roster. Main menu, Settings,
  How to Play, Credits, Dawn Report, victory and loss modals also block
  opening/selection; a new modal closes Research. Space retains normal
  pause behavior. Esc is consumed to avoid also opening Pause.
- **Layout (1280×720):** title "Research", a header "Banked 4 RP · 2
  Researchers (+20 RP/day)" or, with no complete Field Lab, "Build a
  Field Lab and assign Researchers." Below, **three columns** headed by
  the branch icon and name (Defense, Economy, Survivors; icons
  `game/assets/pixel/ui/icon_tech_defense.png`, `icon_tech_economy.png`,
  `icon_tech_survivors.png` from T-224), each with its three upgrade
  cards top to bottom, joined by a short connector line. Header rate
  is the sum for currently working, adjacent, unsuspended Researchers
  after hunger/morale, labelled "RP/day at current speed"; zero if none.
- **Card:** upgrade icon (`game/assets/pixel/ui/tech/<id>.png`, T-214),
  name, cost "20 RP", the one-line player text, and its state:
  - **Locked** (a prerequisite not done): dimmed, "Needs Spotters".
  - **Available:** normal button style; click to research.
  - **Researching:** toggle-on style plus a progress bar "12 / 35 RP".
  - **Done:** done style with "Done"; not clickable.
  Hover shows the full text as a tooltip.
- **HUD readout:** next to the HUD button, "Spotters 12/20" while
  researching, a highlighted "Pick research" when a Field Lab is
  complete and nothing is active, and nothing before day 3 (Field Lab
  unlock).
- **Tutorial hint** `research` (one-shot): the first time a Field Lab
  completes: "Your Field Lab is ready. Make someone a Researcher, then
  press T to choose what they study."
- **How to Play:** one paragraph: "Research. Build a Field Lab (day 3)
  and assign Researchers. Press T to pick one upgrade at a time from
  Defense, Economy or Survivors. Research is optional: the Radio Tower
  never needs it."
- **Dawn Report:** "Research: Spotters 12/20" or "Research done:
  Spotters" (if one finished since the last dawn), only once a Field Lab
  exists. `report["research"] = {"active": id, "progress": float,
  "cost": int, "banked": float, "done_today": [ids]}`. `done_today` contains completion
  ids in completion order since the previous dawn; copy to the report
  then clear before autosave. If active is empty, progress/cost are
  0; if no completion, show "Research: banked N RP" instead of a blank
  active name. A destroyed Lab still permits a report if any tree
  state exists. A partial paused card is Available and shows its saved
  progress; done_today is transient and defaults to [].

### 23.6 Save and `game/data/tech.json`

- **Save:** optional top-level key, `SaveGame.VERSION` stays 1:
  `"tech": {"done": [String], "active": String ("" = none), "progress":
  {id: float}, "banked": float}`. Missing key = empty tree. On restore,
  unknown ids are dropped with a warning, not a failure; `_validate`
  rejects wrong types and numeric ranges per §23.8. Nothing is
  re-applied by hand: effects are
  lookups.
- **Data:**

```json
{
  "rp_per_researcher_per_day": 10,
  "branches": [
    {"id": "defense", "name": "Defense", "icon": "icon_tech_defense"},
    {"id": "economy", "name": "Economy", "icon": "icon_tech_economy"},
    {"id": "survivors", "name": "Survivors", "icon": "icon_tech_survivors"}
  ],
  "upgrades": {
    "spotters": {"branch": "defense", "tier": 1, "name": "Spotters", "cost": 20,
      "requires": [], "effect": {"key": "guard_range_tiles", "op": "add", "value": 1.0},
      "text": "Guards see 1 tile further."}
  }
}
```

(`upgrades` holds all nine rows of §23.3; one is shown. The icon path
is `game/assets/pixel/ui/tech/<id>.png`, derived from the id.)

| Key | Type | Validation (`GameData._validate_tech`) |
|---|---|---|
| `rp_per_researcher_per_day` | number | > 0 |
| `branches` | array of 3 dicts | ids exactly defense, economy, survivors; `name` and `icon` non-empty strings |
| `upgrades` | dict id -> dict | 8 to 12 entries; every branch has at least 2 |
| `.branch` | String | one of the branch ids |
| `.tier` | int | 1-4, unique within its branch |
| `.name`, `.text` | String | non-empty |
| `.cost` | int | > 0 |
| `.requires` | array of String | each an existing upgrade id other than itself; no cycles |
| `.effect.key` | String | one of the nine keys in §23.4 |
| `.effect.op` | String | key/op pair permitted by §23.8 |
| `.effect.value` | number | finite, with per-key ranges and integer-add rules in §23.8 |

A missing or invalid `tech.json` fails `load_from_dir`, and
`_validate_tech` also requires a `field_lab` entry in `buildings.json`
with `workers` >= 1: `"sprite": "field_lab"`, `"name": "Field Lab"`,
`"blurb": "Researchers earn research points by day."`, size [2, 2],
cost 40 wood 15 scrap, hp 150, workers 2, unlock_day 3, build_time 20,
beds 0, `"max_count": 1`.

### 23.7 Build bar and hotkeys

- Keep canonical order by unlock day then wood+scrap cost (tie: id).
  The final 12 placeable buttons are Wooden Wall, Gate, Farm, Shelter,
  Campfire, Storage, Watchtower, Workshop, Lumber Yard, Field Lab,
  Turret, Radio Tower. CC and Reinforced Wall remain filtered out.
  F1-F9 pick the first nine, so F5 Campfire, F8 Workshop, F9 Lumber
  Yard at day 8; the remaining three have no F-key caption.
- T-217 owns the responsive layout: retain one row when its measured
  minimum widths fit the viewport minus 16 px; otherwise split into
  two rows of six (the first six then the rest), anchored at the bottom.
  Every full word, 32 px icon and UiFont.BODY cost stays readable at
  1280×720, with the info card above the top row. No hidden buttons,
  clipping or smaller fonts. T-218 uses the resulting bar as-is.

### 23.8 Exact schema and restore rules (applies also to §22.9)

**Config defaults mean the shipped values, not fallback for malformed
files.** All displayed keys and nested keys are required; missing files,
missing keys, nulls, wrong container types, booleans masquerading as
numbers, nonfinite numbers, and fractional integer fields fail
`GameData.load_from_dir`. JSON parses numbers as floats: an int field
accepts only a finite mathematical integer and is converted with int();
a number accepts a finite int/float. Unknown metadata keys are ignored.
Load each feature into its own dictionary; validation failure never
exposes a partial feature config. Tests copying data dirs add both new
files when both features have landed. No silent default tree or morale
on failed production data loading.

**morale.json complete field contract.** Top-level object; `bands` array
has exactly four objects and `moods` object has exactly the 19 ids in
§22.2. Each mood has exactly the required label:String, value:int,
days:int, stack:int, with the shipped defaults in that table (including
sheltered +2 / 1 / 1). Each band has id:String, name:String, min:int,
work_mult:number, hit_chance:number; defaults are §22.1/§22.9. baseline,
campfire_slots, endless_milestone_every and both breaking fields are
ints; feast is an object with its two int fields;
day_off_morning_fraction:number. The table in §22.9 provides all their
defaults/ranges. Additional validation: mood values within -100..100,
stack within 1..2 (death/left default 2, others 1), Inspired hit_chance
1.0 as well as Steady, multipliers/chances nondecreasing from Breaking
to Inspired, leave_after_dawns >= 2. Named-event labels require {name}
for death/left; other labels may not contain placeholders. The Campfire
entry uses the standard buildings schema (sprite/name/blurb strings,
size array of two positive ints, cost object with nonnegative integer
wood/scrap, positive integer hp, nonnegative integer workers/beds,
integer unlock_day >= 1, positive number build_time); footprint/name/
sprite are fixed, balance numbers have the shipped defaults in §22.9
and can be tuned without rewriting validation constants.

**tech.json complete field contract.** Top-level object with
rp_per_researcher_per_day:number default 10 (>0); branches:array in
Defense/Economy/Survivors order, with exactly the three id/name/icon
string objects and defaults shown in §23.6. upgrades:object has the
nine ids and all shipped field defaults in §23.3 (the lower-case branch
ids from §23.6, not display names). Each entry requires branch:String,
tier:int, name:String, cost:int, requires:array[String], text:String,
effect:object with key:String, op:String, value:number. All strings
nonempty; id uses lower-case ASCII letters/digits/underscores, starting
with a letter. Tier is 1..4, unique and contiguous per branch; tier 1
has requires [], each later tier requires exactly the previous tier id
in its own branch. Reject self, missing, duplicate or cyclic prereqs.
Allow 8..12 entries with at least two per branch as §23.6 specifies;
shipped tree is exactly 3×3. Icon path is derived from id; do not require
upgrade textures to exist while T-214 is still running.

Effect key/op pairs are restricted: guard_range_tiles/add (value >= 0);
turret_fire_interval/mult and gather_time/mult (0 < value <= 1);
structure_damage_taken/mult (0 < value <= 1); farm_food/mult and
campfire_morale/mult (value >= 1); ammo_per_scrap/add, dawn_heal/add,
shelter_beds/add (nonnegative mathematical integers). cost >0. The Field
Lab entry follows the same standard buildings types as the Campfire;
name/sprite/2×2 fixed, workers >=1, optional max_count:int default 0
(unlimited for other buildings), Field Lab requires max_count ==1.
Other Lab defaults are §23.6 and are tunable positive/nonnegative
values. Lookups for absent effect keys return neutral 1.0/0.0.

**Optional save fields.** Missing morale object defaults to
last_feast_day=0; missing survivor moods/breaking_days/refusing defaults
to []/0/false independently. day_off/had_day_off are transient false
after a dawn save; cached morale is recomputed, never serialized.
Each saved mood requires id:String, label:String, value:int (-100..100),
days:int >=1. Preserve ordered labels/values/remaining days exactly;
unknown ids are dropped with a warning, excessive same-id entries keep
the newest configured stack count. breaking_days is an int >=0,
last_feast_day an int in 0..saved day; refusing is bool. A present morale
container must be an object. Missing fields use defaults; present
malformed fields reject the save without changing live state. Do not
re-age moods, rerun DawnRules, heal, or replay arrival/completion events
on restore. The founders' Fresh start is replaced, not inherited.

Missing tech object or its done/active/progress/banked fields defaults
to []/""/{}/0.0 independently. done:array[String], active:String,
progress:object of String -> finite nonnegative number, banked:finite
nonnegative number. Wrong present types/ranges reject the save. Unknown
ids warn and drop, duplicate done ids deduplicate in config order;
remove done ids whose prereqs are not done, repeating until stable.
Progress for unknown/locked/done ids is removed, known progress clamped
to cost, completed progress normalized to done in tier order without
completion toasts. Invalid/locked/done active becomes "". Restoring
never spends the bank or selects research; the next production/choose
command does so. Bunk Beds capacity uses restored tech immediately,
including on the first restored night; RP keeps full floating precision.
`SaveGame.VERSION` remains 1. Saves containing only morale or only tech
are valid, and each module owns only its own optional fields.
