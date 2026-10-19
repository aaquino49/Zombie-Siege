# Architecture and Code Conventions

Engine: **Godot 4.7.2**. Language: **GDScript** with static typing. Renderer: GL Compatibility.
Godot executable: `godot` (on PATH). The project root is `game/`.

## Commands (run from repo root)

| Purpose | Command |
|---|---|
| Re-import assets (after adding files) | `godot --headless --path game --import` |
| Run unit tests | `godot --headless --path game --script res://tests/run_tests.gd` |
| Run ONE test file | `godot --headless --path game --script res://tests/run_tests.gd -- --filter=test_name_or_file` (never pass a `test_*.gd` file to `--script`: test files aren't runnable and Godot hangs) |
| Smoke run (300 frames, headless) | `godot --headless --path game -- --quit-frames=300` |
| Screenshot | `godot --path game --resolution 1280x720 -- --scenario=<name> --screenshot=<ABSOLUTE path>.png --frames=120` |
| Syntax-check one script | `godot --headless --path game --check-only --script res://path/to/file.gd` (always include `--path game`) |
| Export Windows build | `godot --headless --path game --export-release "Windows Desktop" ../builds/ZombieSiege.exe` |
| Play | `godot --path game` |

**Never start Godot without a way to quit.** Every automated run must be headless + `--quit-frames`/`--screenshot`, or the test runner. Running `godot --path game` with no flags opens the game and never returns, which hangs you. So does `-s`/`--script` on a script that doesn't extend SceneTree, or any Godot command without `--path game`. Automated runs (screenshot, quit-frames, headless game) are force-killed by DevTools after 120 s, with an "ERROR: DevTools failsafe" line. If you see it, your code has an infinite loop or never finishes a frame.

The pipeline runs import, tests, smoke, and screenshot automatically after every work step. Any `SCRIPT ERROR`, `Parse Error` or `ERROR:` line in the smoke output counts as a failure.
In the **unit-test** run only `SCRIPT ERROR` / `Parse Error` fail. Negative tests that deliberately trigger a `push_error` (bad data, unknown resource kind) print `ERROR:` lines by design. That's expected and isn't a bug to report. Import, smoke and screenshot output must stay free of `ERROR:` lines.

## Folder layout

```
game/
  project.godot
  scenes/            .tscn files (main.tscn is the entry point)
    world/  units/  buildings/  ui/
  scripts/
    autoload/        singletons (DevTools exists; add Game, Events as needed)
    sim/             PURE LOGIC: RefCounted classes, no Node or scene dependencies -> unit-testable
    world/ units/ buildings/ ui/   Node scripts (presentation + input), thin wrappers over sim
  data/              JSON balance data (buildings.json, zombies.json, waves.json, balance.json)
  assets/            curated art and audio actually used by the game (see project/ART_GUIDE.md)
  dev/scenarios/     screenshot/test scenarios: <name>.gd with `static func setup(main: Node) -> void`
  tests/             test_*.gd extending TestCase (see tests/README.md)
asset_library/       (repo root, outside game/) raw downloaded packs + generated originals. Godot can't see it;
                     copy the files you need into game/assets/ and re-import.
```

## Rules

1. **Separate the simulation from the view.** Game rules (resources, placement validity, jobs, combat math, waves, win/lose) live in `scripts/sim/` as `class_name` RefCounted classes stepped by `tick(delta)`. Nodes read sim state and send it commands. This keeps the rules testable headlessly, and it also enables the balance bot in M4.
2. **Data-driven.** No balance numbers hard-coded in scripts. Load them from `game/data/*.json` through one `GameData` loader.
3. **Static typing everywhere:** `var x: int`, `func f(a: Vector2i) -> bool`. Use `class_name` for reusable classes.
4. **Naming:** files `snake_case.gd/.tscn`, classes `PascalCase`, constants `UPPER_SNAKE`, signals in past tense (`building_placed`).
5. **Signals for decoupling.** A global `Events` autoload holds cross-system signals. Don't use `get_node("../../..")` chains.
6. **Grid helpers in one place.** `const TILE := 64`, with tile/world conversions in a single `Grid` helper.
7. **Pathfinding:** use `AStarGrid2D` for survivors, and a shared flow field or AStarGrid2D (with structure costs) for zombies. Recompute only on map change.
8. **Performance:** pool projectiles, avoid per-frame allocations in hot loops, and keep `_process` work O(entities). Target: 250 zombies + 30 survivors at 60 fps.
9. **No third-party addons or plugins** unless Claude approves (log the approval in decisions.md).
10. **Every logic change ships with tests.** Every visible change keeps or adds a `dev/scenarios/` scenario so screenshots show it. Testing a scene or Node script? Read "Testing scenes and Node scripts" in `game/tests/README.md` first. Nodes in tests are never in the tree, so `_ready` doesn't run and there's no viewport.
11. Keep files under ~400 lines. Split by responsibility.
12. Don't edit `tests/run_tests.gd`, `tests/test_case.gd`, or `scripts/autoload/dev_tools.gd` without a task that says to. The pipeline depends on them.
13. Godot `.import` files and `.uid` files ARE committed. `.godot/` is not.

## Input map

Define actions in project.godot (or in code at startup):
- `cam_left/right/up/down`
- `zoom_in/out`
- `pause`
- `speed_1/2/3`
- `build_menu`
- `cancel`
- `roster`
