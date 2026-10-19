# Zombie Siege

A top-down 2D zombie colony survival game for Windows, made in [Godot 4.7](https://godotengine.org). You lead a handful of survivors camped around a Command Center. **By day** you gather wood and scrap, farm food, place buildings, assign jobs and research upgrades. **By night** zombie waves pour in from the map edges, and your walls, guards and turrets have to hold. Keep your people fed, rested and in good spirits, survive 20 nights, finish the Radio Tower, and hold out until the rescue helicopter comes for you. A full run takes about 40-45 minutes at 1x speed.

**The game was designed, coded, tested and art-directed by a team of AI agents running unattended.** A small Python orchestrator coordinated Claude, Gemini and ChatGPT through 231 tasks and 12 milestones. See [How this was built](#how-this-was-built).

| | |
|---|---|
| Version | 1.7.0 |
| Engine | Godot 4.7.2 (GDScript) |
| Platform | Windows (the Godot project also opens on macOS and Linux) |
| Tests | ~1,000 headless unit and scenario tests |

## Contents

- [Getting started](#getting-started)
- [How to play](#how-to-play)
- [Morale](#morale)
- [Research](#research)
- [Controls](#controls)
- [Project layout](#project-layout)
- [How this was built](#how-this-was-built)
- [Credits](#credits)

## Getting started

Builds aren't committed to this repository, so you run the game from source or export your own exe.

1. Install [Godot 4.7.2](https://godotengine.org/download) and make sure `godot` is on your `PATH`.
2. Clone the repository.
3. Run the game:
   ```
   godot --path game
   ```
   On Windows you can double-click `play.bat`. It runs `builds/ZombieSiege.exe` if you've exported one, otherwise the Godot project.

**Export a Windows exe** (needs the Godot 4.7.2 Windows export templates):
```
godot --headless --path game --export-release "Windows Desktop" ../builds/ZombieSiege.exe
```

**Run the tests:**
```
godot --headless --path game --script res://tests/run_tests.gd
godot --headless --path game --script res://tests/run_tests.gd -- --filter=test_name_or_file
```

**In the game:**
- **New Game** lets you pick **Easy** (hordes 15% smaller), **Normal** or **Hard** (hordes 10% bigger), and shows the map seed with a **Reroll** button.
- The game saves itself at every dawn. **Continue (Day N)** on the main menu resumes your run, and **Reload day** in the pause menu takes you back to the start of the current day.

## How to play

**Goal.** Build the Radio Tower (unlocks on day 8) and survive night 20. Rescue comes at the first dawn after both are true. If the tower isn't finished by night 20, the nights keep coming and keep getting harder until it is. After the rescue you can choose **Keep fighting** to carry on in **endless mode** and see how long the colony lasts.

**You lose** if the Command Center is destroyed or every survivor is gone.

**The day/night loop.**
- **Day** (70 s at 1x): assign jobs, place blueprints, stock up. Builders construct and repair. A line under the top bar forecasts tonight's wave.
- **Night** (at least 40 s, until the wave is cleared, at most 300 s): zombies spawn at the edges and head for the Command Center. Guards and turrets fight on their own. Everyone else shelters. Night 20 is the **Final Horde**.
- **Dawn:** a Dawn Report shows kills, losses, damage, morale and research. Each survivor eats 1 food. Anyone who doesn't eat goes Hungry (half speed), and after 2 hungry days in a row they leave. Spare beds plus plenty of food (at least 2 per survivor) bring 1-2 newcomers.
- **Weather:** from day 2, a day may be **Rainy** (15% chance; farms make 50% more food). From night 5, a night may be **Foggy** (10% chance; guard and turret range drops by 1 tile). Fog never falls on night 20. The forecast warns you in the morning.
- **Scavenging:** in the morning (the first 40% of the day), select a survivor who isn't a guard and press **Send scavenging**. They return at nightfall with wood, scrap, food or ammo, but they may come back hurt or not at all. One run at a time (two from day 10).

**Jobs** (pick from a survivor's info panel or the roster):
- **Gatherer: Wood / Scrap**: harvests the nearest tree or scrap pile and carries it to the Command Center or a Storage.
- **Farmer**: works a Farm (up to 2 per farm).
- **Builder**: builds blueprints and repairs damaged buildings during the day.
- **Crafter**: turns scrap into ammo at a Workshop (daytime only).
- **Guard**: shoots zombies at night (1 ammo per shot, range 5 tiles). Put one on a Watchtower for extra range and protection.
- **Researcher**: works at the Field Lab by day (up to 2) and makes 10 research points per full day.
- **Idle**: does nothing. The **Idle: N** button in the top bar (or I) finds idle survivors.

**Buildings** (the cost is paid when you place the blueprint):

| Building | Cost | Unlocks | What it does |
|---|---|---|---|
| Command Center | - | start | Drop-off point and 4 beds. **Lose it and you lose.** |
| Wooden Wall | 5 wood | day 1 | Blocks zombies (200 HP). Drag to place a line. |
| Gate | 10 wood | day 1 | A wall your survivors can walk through. |
| Shelter | 30 wood | day 1 | +4 beds and a safe place at night. |
| Farm | 20 wood | day 1 | +8 food per farmer per day (up to 2 farmers). |
| Storage | 25 wood | day 2 | Extra drop-off point for gatherers. |
| Campfire | 15 wood | day 2 | Cheers up to 6 survivors every morning (+6 morale). |
| Watchtower | 25 wood, 5 scrap | day 2 | 1 guard gets +50% range and protection. |
| Workshop | 30 wood, 10 scrap | day 2 | A crafter makes 12 ammo from 1 scrap every 5 s. |
| Lumber Yard | 30 wood | day 3 | +50% chopping speed within 6 tiles. |
| Field Lab | 40 wood, 15 scrap | day 3 | Up to 2 Researchers earn research points by day. Only one per colony. |
| Turret | 10 wood, 25 scrap | day 4 | Auto-fires at zombies within 6 tiles, 2 shots a second (uses ammo). |
| Reinforced Wall | 5 wood, 5 scrap | day 6 | Upgrade a finished Wooden Wall (select it, press Upgrade). 400 HP. |
| Radio Tower | 150 wood, 120 scrap | day 8 | Long build. Required to win. |

**Tips.**
- **Farm first.** Food runs out fast, and hungry survivors work at half speed, lose morale and then leave.
- **Wall in before night 4.** That's when runners arrive and the waves start coming from two sides. Leave a Gate so your workers can get out.
- **Build a Workshop early.** Guards and turrets use 1 ammo per shot, and you start with only 40.
- **Put up a Campfire and enough beds early.** A Steady colony works at full speed; Low guards start missing shots. Save a Feast for after a bad night.
- **Build the Field Lab on day 3 or 4.** One Researcher from day 4 earns about five upgrades by night 20. Spotters and Better Tools are cheap, strong first picks.
- **Start the Radio Tower soon after day 8.** It costs 150 wood and 120 scrap and takes a long time to build, so save scrap for it and have it done before night 20.
- Spitters (from night 8) stop out of reach and spit acid at turrets and watchtowers. Keep guards and turrets covering each other.
- Brutes (from night 11) go after walls. Upgrade to Reinforced Walls and keep a builder on repairs.

The main menu also provides How to Play and Credits. Back or Esc returns to the menu that opened each screen.

## Morale

Every survivor has a morale score from 0 to 100 (shown in the roster and info panel). New arrivals start at 60. It moves with their moods and drifts back towards 50 as moods wear off after a few dawns: a bed (+5), a warm campfire (+6) or a quiet night (+4) help; no bed (-10), going hungry (-15), being badly hurt (-8), a rough night (-6) or a friend dying (-12) hurt.

| Band | Morale | Work speed | Guard hits |
|---|---|---|---|
| Inspired | 75-100 | 115% | every shot |
| Steady | 40-74 | 100% | every shot |
| Low | 20-39 | 85% | 85% of shots |
| Breaking | 0-19 | 70% | 70% of shots |

- **Breaking:** a survivor who is Breaking at dawn refuses to work that day (a Breaking guard leaves the wall). Breaking at two dawns in a row, they leave the colony. At most one survivor leaves this way per dawn.
- **What you can do:** keep beds and food ahead of your headcount, build a Campfire, hold a **Feast** (Command Center panel, by day: 2 food per survivor, +10 morale for 3 days, once every 3 days), or give someone a **Day off** in the morning (they skip work and get +12 the next dawn). Good defences mean quiet nights, and finishing the Radio Tower lifts everyone (+10).
- Turrets never miss; morale only affects survivors.

## Research

Build a **Field Lab** (day 3, one per colony) and make up to 2 survivors **Researchers**. Each makes 10 research points (RP) per full day of work, slower when hungry or low on morale. Press **T** (or the research button in the top bar) to open the tech tree and pick one upgrade at a time. Switching keeps progress, and points made with nothing picked are banked, never lost.

| Branch | Tier 1 (20 RP) | Tier 2 (35 RP) | Tier 3 (50 RP) |
|---|---|---|---|
| Defense | Spotters: guards see 1 tile further | Oiled Turrets: turrets fire 25% faster | Reinforced Frames: buildings take 25% less damage |
| Economy | Better Tools: gatherers work 25% faster | Crop Rotation: farms grow 25% more food | Ammo Press: Workshops make 3 more ammo per scrap |
| Survivors | Camp Songs: Campfires give 50% more morale | First Aid: survivors heal 10 HP each dawn | Bunk Beds: each Shelter has 2 extra beds |

Each tier needs the one above it in its branch. All nine cost 315 RP. Research is optional: **the Radio Tower and the win never need it.**

## Controls

| Action | Input |
|---|---|
| Pan camera | WASD or arrow keys, or move the mouse to the screen edge |
| Zoom (0.5x to 2x) | Mouse wheel, or `=` (`+`) and `-` |
| Pause / resume | Space |
| Game speed 1x / 2x / 3x | 1 / 2 / 3 |
| Build menu | B, or the build bar |
| Pick a building | F1-F9 pick the first nine build-bar buttons (the key is shown on each button) |
| Place building | Left-click. Shift+click keeps the building selected so you can place more. |
| Place a line of walls | Left-click and drag (Wooden Wall) |
| Cancel placement | Right-click or Esc |
| Select survivor or building | Left-click (opens the info panel: job, HP, morale, workers, Upgrade, Day off, Send scavenging, Feast) |
| Deselect | Right-click or Esc |
| Survivor roster | R |
| Tech tree (research) | T (Esc or T closes it) |
| Next idle survivor | I, or click **Idle: N** in the top bar |
| Pause menu | Esc (when nothing is selected and you're not placing). Resume, Restart, Reload day, Settings, Quit to Menu. |
| Close the Dawn Report | Enter or Space, or click Continue |

Tutorial hints appear in the top-left corner the first time each one matters. They never pause the game and can be turned off in Settings, available from the main menu or pause menu. Settings also saves audio levels, window mode, screen shake and the default speed for new games.

## Project layout

```
game/                 The Godot project
  scripts/sim/        Game rules as plain RefCounted classes (no nodes), so they test headlessly
  scripts/            Nodes, UI and autoloads that read the sim and send it commands
  scenes/             Godot scenes
  data/balance.json   Tunable numbers: costs, timings, wave sizes
  assets/             Processed sprites, audio and fonts used by the game (see assets/ASSET_INDEX.md)
  dev/scenarios/      Scripted set-ups used for automated screenshots and smoke tests
  tests/              Unit and scenario tests, run by tests/run_tests.gd
asset_library/        Source art and audio packs, licence evidence, and the scripts that process them
orchestrator/         The Python orchestrator that ran the AI team, and its config
project/              The team's working files: game design doc, task board, task briefs,
                      decisions, assumptions, milestone reports and the team protocol
CREDITS.md            Art, audio and font credits with licences
```

Useful documents: [`project/GDD.md`](project/GDD.md) (game design), [`project/ARCHITECTURE.md`](project/ARCHITECTURE.md) (code conventions and commands), [`project/PROTOCOL.md`](project/PROTOCOL.md) (how the agents work together).

## How this was built

No person wrote the game's code. The owner set the brief, answered occasional requests in [`project/OWNER_REQUESTS.md`](project/OWNER_REQUESTS.md), and played the builds. Everything else was done by AI agents coordinated by a plain script:

| Role | Who | Job |
|---|---|---|
| Quarterback | **Claude** (Claude Code CLI) | Product manager, project manager, tech lead and final reviewer. Owns the design doc, plans milestones, writes task briefs, approves or sends back work. |
| Coder | **Gemini** (Antigravity CLI) | Implements code tasks. |
| QA and art | **ChatGPT** (Codex CLI) | Writes and runs tests, playtests through screenshots, files bugs, curates asset packs and generates missing art. |
| Orchestrator | [`orchestrator/orchestrator.py`](orchestrator/orchestrator.py) | No AI. Picks the next task, calls the right agent, runs the checks, commits to git, and is the only writer of the task board. |

**Each task goes through the same pipeline:**

```
backlog -> ready -> WORK -> CHECKS -> QA -> CHECKS -> REVIEW -> commit -> done
                      ^                                  |
                      +------- revise (max 3 tries) -----+
```

- **CHECKS** run automatically after every step: Godot import, the full test suite, a headless smoke run and screenshots of `dev/scenarios/`. Any script error fails the step.
- If a task fails three times, its changes are reverted and Claude re-plans it.
- Agents never touch git or the task board directly; they report through a JSON result file, and the orchestrator does the rest.
- When an agent's subscription hit its usage limit, the orchestrator read the reset time and routed the step to a fallback agent (set in `orchestrator/config.json` under `fallback`), so the team kept working overnight.
- A second git worktree ("lane B") let two code tasks run in parallel.
- Optional phone alerts go through [ntfy.sh](https://ntfy.sh). Put your topic in an untracked `orchestrator/config.local.json`, for example `{"notify": {"ntfy_topic": "your-secret-topic"}}`. Anyone who knows a topic can read and post to it.

**By the numbers:** 231 tasks (198 shipped, 33 dropped), 12 milestones, about 1,000 automated tests, and version 1.7.0 at the end. Every planning decision is logged in [`project/decisions.md`](project/decisions.md), and every judgment call an agent made on its own is in [`project/assumptions.md`](project/assumptions.md).

### Running the team yourself

You'll need Python 3, Godot 4.7.2 on your `PATH`, and the agent CLIs named in `orchestrator/config.json` (`claude`, `agy`, `codex`, `opencode`), each signed in. Then:

| Want to... | Do this |
|---|---|
| Start or resume the team | `start.bat` (keep the window open and the PC awake) |
| See what's happening | `project/STATUS.md` updates live; the event log is `project/events.log` |
| Ask for a change | Add a line under **Open** in `project/OWNER_REQUESTS.md`. Claude turns it into tasks at its next planning step. |
| Stop | `stop.bat` stops after the current step; closing the window stops immediately |
| Restart it if it dies | `supervise.bat` relaunches the orchestrator until the project is complete |

The agent CLIs run with their permission prompts turned off, so run the team on a machine and folder you're comfortable giving them.

## Credits

- **Pixel art:** processed from [Ittai Manero](https://ittaimanero.itch.io)'s [*Zombie Apocalypse Tileset*](https://ittaimanero.itch.io/zombie-apocalypse-tileset), used under the pack's free-for-commercial-use terms. The raw pack isn't redistributed here; only the processed sprites the game uses are included. To re-run the asset pipeline, download the pack and unpack it into `asset_library/ittaimanero/`.
- **Other art and sound effects:** [Kenney](https://kenney.nl) (CC0) and several CC0 tracks from [OpenGameArt](https://opengameart.org).
- **Font:** Pixelify Sans and a modified version of it, under the SIL Open Font License 1.1.
- A few sprites (such as the rescue helicopter) and some sound effects were generated by the AI team.

Full per-file credits and licence evidence are in [`CREDITS.md`](CREDITS.md).
