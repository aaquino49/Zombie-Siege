# Supervisor handoff (2026-10-12 ~23:00)

The supervising Claude session is near its usage limit. Any agent picking this up (Codex, or a new Claude session) should work from this note.

## State
- Team running via `start.bat` → `orchestrator/orchestrator.py`: two lanes, auto-restart on crash.
- **Final milestone: M12.** `stop_after_milestone = M12` in `orchestrator/config.json` stops the team automatically when M12 completes.
- M12 remaining (in order): T-220 balance v6 (in progress) → T-221 final QA → T-222 v1.7.0 Windows export.
- Current build: `builds/ZombieSiege.exe` v1.6.0. v1.7.0 comes from T-222.
- Quota:
  - **Gemini:** out until ~Fri Oct 16 21:00 (weekly cap; agy also rejects `gemini-3.1-pro-high`, which is harmless).
  - **OpenAI:** handed off early at 96% of its 5-hour window (resets ~00:55). The owner can apply Codex limit resets; the orchestrator notices within ~15 min.
  - **Claude:** near its limit; Codex, then Muse, cover its roles automatically.
  - **Fallback:** Muse Spark (`opencode run -m meta/muse-spark-1.3-contributor`).

## How to watch
- Live status: `project/STATUS.md`. Event log: `project/events.log`. Owner requests: `project/OWNER_REQUESTS.md`.
- Alive check: a `python orchestrator\orchestrator.py` process exists.
- Owner alerts are sent by the orchestrator itself via ntfy.sh topic set in the untracked `orchestrator/config.local.json` (`notify.ntfy_topic`), viewable in a browser at `https://ntfy.sh/<topic>`.

## If something breaks
- Reload code between tasks: create `project/RESTART`. Stop: create `project/STOP`. Start: run `start.bat` via `explorer.exe`.
- Don't edit `project/board.json` while the orchestrator runs (it owns it). Steer the team through `project/OWNER_REQUESTS.md`.
- Commit orchestrator changes before touching `project/RESTART`.

## Done when
- The events log shows `FINAL MILESTONE M12 complete` and `PROJECT COMPLETE`, and `builds/ZombieSiege.exe` reports 1.7.0.
