"""Repeat verbose 300-frame smoke tests, retaining every log and exit code.

python project/tools/smoke_loop.py --run-dir <attempt folder> --godot godot_console
"""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import time


ROOT = Path(__file__).resolve().parents[2]
BAD_OUTPUT = re.compile(
    r"leaked|still in use at exit|ObjectDB instances|SCRIPT ERROR|Parse Error|ERROR:",
    re.IGNORECASE,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--godot", default="godot_console" if os.name == "nt" else "godot")
    parser.add_argument("--uncapped", type=int, default=20)
    parser.add_argument("--capped", type=int, default=5)
    parser.add_argument("--repo", type=Path, default=ROOT)
    args = parser.parse_args()
    executable = shutil.which(args.godot)
    if executable is None:
        parser.error("Godot executable not found: " + args.godot)
    args.run_dir.mkdir(parents=True, exist_ok=True)
    report = []
    for label, count, cap in [("uncapped", args.uncapped, []), ("capped", args.capped, ["--max-fps", "60"])]:
        for index in range(1, count + 1):
            command = [executable, "--headless", "--path", str(args.repo / "game"), "--verbose", *cap, "--", "--quit-frames=300"]
            log = args.run_dir / f"smoke_{label}_{index:02d}.log"
            started = time.monotonic()
            timed_out = False
            with log.open("w", encoding="utf-8") as output:
                try:
                    result = subprocess.run(command, cwd=args.repo, stdout=output, stderr=subprocess.STDOUT, timeout=120, check=False)
                    exit_code = result.returncode
                except subprocess.TimeoutExpired:
                    timed_out = True
                    exit_code = None
            problems = [line for line in log.read_text(encoding="utf-8", errors="replace").splitlines() if BAD_OUTPUT.search(line)]
            passed = exit_code == 0 and not problems and not timed_out
            report.append({"mode": label, "run": index, "command": command, "log": log.name, "exit_code": exit_code, "seconds": round(time.monotonic() - started, 3), "timed_out": timed_out, "problems": problems, "passed": passed})
            print(f"{label} {index}/{count}: {'PASS' if passed else 'FAIL'} ({report[-1]['seconds']}s)", flush=True)
    passed = bool(report) and all(run["passed"] for run in report)
    (args.run_dir / "smoke_loop_results.json").write_text(json.dumps({"passed": passed, "runs": report}, indent=2) + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
