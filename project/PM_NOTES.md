# PM Notes

_Last updated: 2026-10-13, PLAN 01:52_

## Where we are

**The project is finished.** v1.7.0 is exported and M12, the final
milestone you set in R-11, is complete. I have set `project_complete`,
so the orchestrator should stop the team after this plan.

Since the last plan:
- **T-230** the Day-1 welcome card now fits its text and no longer
  hides the F1 Wooden Wall button. Approved first try.
- **T-231** README.md refreshed for v1.7.0 (morale, research, Campfire,
  Field Lab, Researcher, T hotkey; every number checked against data).
- **T-222** `builds/ZombieSiege.exe` is v1.7.0 (FileVersion 1.7.0.0).
  1024 tests pass, import and smoke are clean, and the release exe
  was checked on the default, tutorial, research and morale screens.

## What shipped in M12

- Survivor morale: moods with reasons, work speed and guard accuracy
  effects, Breaking, and levers (Campfire, feast, Day off).
- Research: Field Lab, Researcher job, nine upgrades in three
  branches, and a Research screen on T. The Radio Tower win is
  unchanged.
- Balance v6: Hard wins 6 of 10 seeds, Normal has no losses.

Full report: `project/milestones/M12.md`.

## Still open for the owner

- `orchestrator/config.json` still asks agy for `gemini-3.1-pro-high`,
  which agy no longer recognises. I have not touched the config.
- Normal wins 5 of 10 seeds; the other five survive to night 20
  without building the Radio Tower. Accepted for this release.

## Note on the plan prompt

The plan prompt still carried the generic "expansion mode: never set
project_complete" text. Your R-11 request is specific and newer, so I
followed it: no M13, no new tasks, `project_complete: true`. If you
want more work, add a request under "Open" in `OWNER_REQUESTS.md`.
