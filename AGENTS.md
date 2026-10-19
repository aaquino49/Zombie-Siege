# Zombie Siege: Agent Instructions

This repository is built by an autonomous team of AI agents run by `orchestrator/orchestrator.py`.

- Your role and exact instructions are in the prompt file the orchestrator gave you. Role guides:
  - ChatGPT/Codex: `project/roles/qa_assets.md`
  - Gemini: `project/roles/coder.md`
  - Claude: `project/roles/quarterback.md`
- Team rules and output formats: `project/PROTOCOL.md`
- Game design: `project/GDD.md`. Code conventions and commands: `project/ARCHITECTURE.md`. Art: `project/ART_GUIDE.md`.

Hard rules:
- No human is available. Never ask questions. Log assumptions in `project/assumptions.md`.
- Never run `git commit/reset/checkout/stash`. Never edit `project/board.json`.
- Always finish by writing the JSON output file named in your prompt.
