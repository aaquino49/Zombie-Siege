# Zombie Siege v1 release checklist

T-034, attempt 1; checked 2026-10-11 against checkpoint `2d93326dc4f80927d90223c1f291268e7edde6b3`.
**Release gate: PASS.** No defects found; `project/runs/T-034/a1/bugs.json` is empty.

Evidence paths below are relative to the repository root. Raw stdout, stderr, commands, exit codes and
timings are retained in `project/runs/T-034/a1/`. The machine-readable gate is
`project/runs/T-034/a1/evidence_summary.json`.

| Item | How checked | Result pass/fail | Evidence path |
| --- | --- | --- | --- |
| 1a. Import clean | Godot 4.7.2 headless import; exit 0; stdout/stderr contain no `ERROR:`, SCRIPT ERROR, parse error or ObjectDB/resource leak lines. | PASS | `project/runs/T-034/a1/import.log`, `import.err.log`, `import.result.json` |
| 1b. Full suite passes, count and no SCRIPT ERROR | Full runner after adding two regressions: **506 passed, 0 failed**, exit 0. No SCRIPT ERROR, parse error or leaks. The 29 deliberate invalid-data/unknown-resource `ERROR:` lines are expected negative tests under ARCHITECTURE.md. Backtraces identify those tests. | PASS | `project/runs/T-034/a1/tests.log`, `tests.err.log`, `tests.result.json`; `game/tests/test_release_gate_qa.gd` |
| 1c. 300-frame smoke clean | Source project, headless, `--quit-frames=300`; exit 0; no `ERROR:` or ObjectDB/resource leak lines in either stream. | PASS | `project/runs/T-034/a1/smoke.log`, `smoke.err.log`, `smoke.result.json` |
| 2a. Export exists and size recorded | Existing T-033 single-file release executable retained; **112,895,536 bytes** (107.67 MiB). SHA-256 recorded in evidence summary. Re-export was unnecessary. | PASS | `builds/ZombieSiege.exe`; `project/runs/T-034/a1/evidence_summary.json` |
| 2b. Export headless smoke | Run executable with `--headless -- --quit-frames=120`; exit 0, no errors/leaks. | PASS | `project/runs/T-034/a1/exe_headless.log`, `exe_headless.err.log`, `exe_headless.result.json` |
| 2c. Export windowed smoke opens/closes | Run executable with `-- --quit-frames=120`; its visible native window was enumerated, OpenGL initialized, process closed normally with exit 0. No errors/leaks. | PASS | `project/runs/T-034/a1/exe_windowed.log`, `exe_windowed.err.log`, `exe_windowed.result.json` |
| 3a. Balance, five seeds, both strategies | Run `balance_run.gd` with seeds 1337,1,2,3,4, both strategies. Sensible **5/5 wins**, exceeding the >=3 target. None loses the CC on **night 4 in all five** (summary reports 3 nights survived; per-seed CSV records loss on night 4). No tick cap or errors. BALANCE lines pasted below. | PASS | `project/runs/T-034/a1/balance.log`, `balance.err.log`, `balance/summary.csv`, `balance/none_1337.csv` and the other per-seed CSVs |
| 3b. Accepted T-098 full-run length | New regression measures seed-1337 sensible win at **2510.50 simulated seconds**, matching the recorded 2510 s / **41:50** target within whole-second rounding and the 40–45 min range. Exported natural-rescue scenario independently records the same time and displays 41:50. | PASS | `project/decisions.md` T-098; `game/tests/test_release_gate_qa.gd`; `project/runs/T-034/a1/tests.log`, `screenshot_qa_m4_victory.log`, `qa_m4_victory.png` |
| 4. Required screenshot scenarios | All nine required scenarios run from the exported executable at 1280x720, exit 0, save PNG with err=0, and have no errors/leaks. Inspected all in a contact sheet; tutorial, dawn, pause and Victory also inspected at full size. Source default screenshot additionally passes the orchestrator command. Details below. | PASS | `project/runs/T-034/a1/release_contact_sheet.png`; nine scenario PNGs and `screenshot_<scenario>.log/.err.log/.result.json`; `source_default.png`, `screenshot_source_default.log` |
| 5. Live menu/new game/pause/restart/menu/terminal flow | Existing `qa_m4_menu_flow.gd` run with the editor engine: **115 checks, 0 failures**, exit 0. Real New Game, Esc/Resume, Restart, Quit to Menu, both Game Over reasons and their buttons, both Victory buttons, dawn Continue, state cleanup and locked clocks all pass. Exported build independently completes natural rescue and Victory. | PASS | `game/dev/scenarios/qa_m4_menu_flow.gd`; `project/runs/T-034/a1/live_flow.json`, `live_flow.log`, `live_flow.err.log`; `screenshot_qa_m4_victory.log` |
| 6a. Each tutorial hint once | Existing tutorial regressions plus new single-game card lifecycle test display/dismiss welcome, farm, night soon, ammo, hunger and radio, then verify no repeats and no pause. Existing regressions verify 12 s timeout, queueing and new-game reset. Export screenshot confirms card layout. | PASS | `game/tests/test_release_gate_qa.gd`, `test_tutorial_hints.gd`, `test_tutorial_hints_qa.gd`; `project/runs/T-034/a1/tests.log`, `tutorial.png` |
| 6b. Pause Hints toggle persists | New live scenario changes the real CheckButton, checks saved setting and disabled cards, restarts through the button, verifies loaded CheckButton, then re-enables hints. Original settings bytes restored after check. | PASS | `game/dev/scenarios/qa_t034_release.gd`; `project/runs/T-034/a1/release_live.json`, `release_live.log`, `release_live.err.log` |
| 7a. Audio error-free | No audio/runtime errors or leaks during export headless/windowed smoke, nine export screenshots, full exported rescue, or live flows. Full suite's audio-manager and audio-bus regressions pass. This checks errors/wiring, not subjective listening quality. | PASS | `project/runs/T-034/a1/evidence_summary.json`, `tests.log`, `screenshot_qa_m4_victory.log`; `game/tests/test_audio_manager.gd`, `test_pause_menu.gd` |
| 7b. Volume sliders persist | Real pause Master/SFX/Music sliders set to 23/47/61%, restart through real button, verify slider values and saved linear values for all three. Hint/audio coexistence regressions pass; original settings restored. | PASS | `project/runs/T-034/a1/release_live.json`, `live_flow.json`, `tests.log`; `game/dev/scenarios/qa_t034_release.gd` |
| 8. All shipped third-party/generated art/audio credited | Enumerated **98 assets: 76 PNG, 1 ICO, 11 OGG, 10 WAV**. Every asset has a manifest row and a credited source family; no uncovered files. Reviewed credit sections, manifest and local provenance for Kenney, composed title/buildings/paths, AI helicopter, downloaded CC0 audio and generated cues. Import metadata/documentation introduce no additional source. | PASS | `CREDITS.md`; `game/assets/ASSET_INDEX.md`; `project/runs/T-034/a1/asset_audit.json`, `audit_assets.py` |
| 9. All GDD §11 controls and UI | Exported `qa_m1_inputs` live input checks report **0 failures, 0 limitations**, including OS-focus edge pan. New source live scenario adds B/R/Esc, selection/job UI and pause settings. Existing passing tests cover remaining UI presentation and feedback. Detailed mapping below. | PASS | `project/runs/T-034/a1/exe_inputs.json`, `exe_inputs.log`, `exe_inputs.png`, `release_live.json`, `tests.log`; `game/dev/scenarios/qa_m1_inputs.gd`, `qa_t034_release.gd` |

## Balance evidence

Raw lines from `project/runs/T-034/a1/balance.log`:

```text
BALANCE seed=1337 strategy=sensible outcome=won nights=20 cc=100.0% ms=9208
BALANCE seed=1337 strategy=none outcome=lost_cc nights=3 cc=0.0% ms=316
BALANCE seed=1 strategy=sensible outcome=won nights=20 cc=100.0% ms=8940
BALANCE seed=1 strategy=none outcome=lost_cc nights=3 cc=0.0% ms=293
BALANCE seed=2 strategy=sensible outcome=won nights=20 cc=100.0% ms=9975
BALANCE seed=2 strategy=none outcome=lost_cc nights=3 cc=0.0% ms=326
BALANCE seed=3 strategy=sensible outcome=won nights=20 cc=100.0% ms=10245
BALANCE seed=3 strategy=none outcome=lost_cc nights=3 cc=0.0% ms=291
BALANCE seed=4 strategy=sensible outcome=won nights=20 cc=100.0% ms=9218
BALANCE seed=4 strategy=none outcome=lost_cc nights=3 cc=0.0% ms=232
BALANCE_SUMMARY strategy=sensible runs=5 won=5 survived=0 lost=0 median_nights=20.0 min_cc=100.0%
BALANCE_SUMMARY strategy=none runs=5 won=0 survived=0 lost=5 median_nights=3.0 min_cc=0.0%
```

## Screenshot inspection

Every PNG below is under `project/runs/T-034/a1/`; corresponding stdout/stderr and exit-code JSON use
the `screenshot_<name>` prefix. Each result is PASS.

| Scenario / PNG | Inspection | Result |
| --- | --- | --- |
| `default.png` | Starting camp, centered CC, readable resources/time/speed, roster and four starting buildings. | PASS |
| `main_menu.png` | Title background and centered title, goal, New Game and Quit; no clipping. | PASS |
| `tutorial.png` | Welcome card under roster, readable text and Got it; gameplay and build bar remain visible. | PASS |
| `night.png` | Night tint, first wave and live zombie count; resource/time/build controls remain readable. | PASS |
| `final_night.png` | Day 20, red/dark final-night tint and final horde count; visible wave and HUD. | PASS |
| `dawn_report.png` | Casualties, damage, food, newcomer, unlock/objective rows and Continue fit the viewport. | PASS |
| `pause_menu.png` | Resume/Restart/Main Menu, three labeled sliders and Hints CheckButton fit without overlap. | PASS |
| `game_over.png` | Defeat reason, five stats, Restart and Main Menu are readable. | PASS |
| `qa_m4_victory.png` | Natural helicopter completion shows RESCUED, 20 nights, all stats, 41:50 and both buttons. Six live scenario assertions pass. | PASS |

`qa_m4_victory` drives a full game asynchronously and sets its own screenshot deadline after the natural
helicopter animation. It uses `--frames=10000000` plus the existing 120 s failsafe; it finishes in 16.5 s.
An initial 120-frame image captured the coroutine halfway through the game and was replaced by the
completed capture. The source pipeline default additionally renders to `source_default.png` at 120 frames.

## GDD §11 control and UI coverage

| Control / UI | How checked / evidence | Result |
| --- | --- | --- |
| WASD and arrows | All eight physical keys move the real exported camera in the expected direction; `exe_inputs.json`. | PASS |
| Edge pan | Focused window, OS cursor warped to all four edges; zero input limitations; `exe_inputs.json`. | PASS |
| Mouse wheel, 0.5x–2x zoom and map clamp | Real wheel events, cursor anchor and both bounds, map corners at three zoom levels; `exe_inputs.json`; camera tests in `tests.log`. | PASS |
| Space; 1/2/3 | Real physical events toggle pause and all speeds, HUD active button updates, paused clock stays frozen while camera moves; `exe_inputs.json`. | PASS |
| B and build bar | Real B toggles twice in `release_live.json`; actual export build-bar mouse selection does not place/spend; `exe_inputs.json`. | PASS |
| Left-click placement; Shift-click repeat | Export live input creates two gates with Shift and retains build mode; `exe_inputs.json`. | PASS |
| Right-click / Esc cancels | Export live build-mode cancel and real source Esc selection/pause routing; `exe_inputs.json`, `release_live.json`. | PASS |
| Drag walls | Export live press/release places line, stops at available wood and exits non-Shift build mode; `exe_inputs.json`; build-mode tests. | PASS |
| Survivor/building selection and job/HP/workers info | Live selection command opens info, job dropdown assigns builder, building info shows HP; `release_live.json`. Selection radius, building fallback, worker count and cross-panel job synchronization tests pass in `tests.log`. | PASS |
| R and roster quick jobs | Real physical R opens/closes roster; `release_live.json`. Row selection, job assignment and population/scroll coverage in `test_roster_panel.gd` and `test_selection_ui_qa.gd`, passing in `tests.log`. | PASS |
| Resource/top bar, phase/zombie count, speed buttons | Export input verifies icons and current amounts; screenshots show phase/time/count. HUD/clock-button tests pass in `tests.log`. | PASS |
| Health bars, gathering popups, CC attack flash | Building/zombie/survivor view, floating-text and combat-FX tests pass in `tests.log`; full rescue exercises the live FX layer without errors. | PASS |
| Main/Pause/Game Over/Victory/Dawn screens | Required PNGs plus 115-check live flow and natural exported Victory; `live_flow.json`, `qa_m4_victory.png`. | PASS |
| Tutorial close/timeout, no pause, once per game | Both new card-cycle and existing timeout/reset tests pass; `tests.log`, `tutorial.png`. | PASS |

## Scope and diagnostic notes

- Two new regression tests pass. Only QA scenario/test files and their generated UID metadata,
  release documentation and an appended assumption were changed. No production scripts, scenes,
  data, assets, export preset or executable changed. The pre-existing `project/board.json` change
  belongs to the orchestrator and was left untouched.
- Source script harnesses provide unit/balance/menu-flow checks; the retained export provides smoke,
  input-routing, screenshot and full natural-rescue checks. The release executable ignores engine
  `--script`, so exploratory `exe_balance` and `exe_live_flow` logs are explicitly excluded from the
  gate. The latter was stopped; these are unsupported harness invocations, not game failures.
- The initial pacing assertion was too strict for a whole-second recorded target (2510.50 versus
  2510). It was corrected to 1 s tolerance; `tests_initial.*` retains that diagnostic, while `tests.*`
  is the final passing run.
- README launch/export, goal, pacing and controls were also reviewed against the build and GDD;
  no discrepancies affecting play were found.
