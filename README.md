# Zombie Siege

A top-down 2D zombie colony survival game for Windows. You lead a handful of survivors camped around a Command Center. **By day** you gather wood and scrap, farm food, place buildings, assign jobs and research upgrades. **By night** zombie waves pour in from the map edges, and your walls, guards and turrets have to hold. Keep your people fed, rested and in good spirits, survive 20 nights, finish the Radio Tower, and hold out until the rescue helicopter comes for you. A full run takes about 40-45 minutes at 1x speed.

## Play

- **Current version: 1.7.0.**
- **Windows build:** run `builds/ZombieSiege.exe`. No install needed.
- **From source:** install [Godot 4.7.2](https://godotengine.org), then double-click `play.bat` (it runs the exe if there is one, otherwise the project) or run `godot --path game`.
- **Rebuild the exe** (needs the Godot 4.7.2 Windows export templates):
  ```
  godot --headless --path game --export-release "Windows Desktop" ../builds/ZombieSiege.exe
  ```
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

## Credits

Art is mostly by [Kenney](https://kenney.nl) (CC0), with a few AI-generated sprites. Full credits for art and audio are in [`CREDITS.md`](CREDITS.md).

## How this was built

Zombie Siege was built autonomously in Godot 4.7 by an AI team:

- **Claude** (Claude Code CLI): quarterback. Product manager, project manager, tech lead, final reviewer.
- **Gemini 3.1 Pro** (Antigravity CLI `agy`): main coder.
- **ChatGPT** (Codex CLI): QA, art curation and image generation.
- **`orchestrator/orchestrator.py`**: a plain script that runs the loop, calls the agents, runs the build and tests, and commits to git.

## For the owner

| Want to... | Do this |
|---|---|
| Start or resume the team | Double-click `start.bat` (keep the window open, and keep the PC on and plugged in) |
| See what's happening | Open `project/STATUS.md` (updates live) |
| Read Claude's PM notes | `project/PM_NOTES.md`, and `project/milestones/` for milestone reports |
| Stop | Double-click `stop.bat` (stops after the current step), or close the window (stops immediately; the interrupted task restarts cleanly next time) |
| Play the latest version | Double-click `play.bat` |
| Ask for a change or feature | Add a line under **Open** in `project/OWNER_REQUESTS.md`. Claude turns it into tasks at its next planning step. |
| See every change | `git log --oneline` in this folder |

How it works and the rules the agents follow: `project/PROTOCOL.md`. Game design: `project/GDD.md`.

### Notes
- **Run mode (owner's instruction, updated 2026-10-10):** the team keeps going through v1 (M0–M5) and then expansion milestones (M6, M7, ...). Usage limits don't stop it. When a subscription hits its limit, the orchestrator reads the reset time and routes around it: Google out → Codex (GPT-6.1-Sol) codes; Codex QA and art always use GPT-6.1-Sol. **Last resort:** if the subscriptions that could cover a step are all out, the team uses Meta Muse Spark 1.3 contributor tier (`meta/muse-spark-1.3-contributor` via OpenCode, the owner's cheap paid API). OpenAI out → Gemini does QA and art tasks. Anthropic out → Codex reviews, while planning waits. It sleeps only when nobody can do the next step. Policy lives in `orchestrator/config.json` (`fallback`).
- The project lives in OneDrive. If you see duplicate "conflict" files, pause OneDrive syncing while the team runs.
- The orchestrator keeps the PC awake while it runs. It can't stop Windows Update restarts.
