"""Lightweight, AI-free supervisor: keeps the orchestrator alive until the project completes.

Every 2 minutes: if no `orchestrator.py` process is running, the run hasn't been stopped (project/STOP) and the
project isn't complete, relaunch start.bat and post an ntfy alert. Exits when the events log shows PROJECT COMPLETE.
"""
import json
import subprocess
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EVENTS = ROOT / "project" / "events.log"
CONFIG = json.loads((ROOT / "orchestrator" / "config.json").read_text(encoding="utf-8"))
# Owner-only settings (the ntfy topic) live in the untracked config.local.json; its keys override config.json's.
_LOCAL_CONFIG = ROOT / "orchestrator" / "config.local.json"
if _LOCAL_CONFIG.exists():
    for _k, _v in json.loads(_LOCAL_CONFIG.read_text(encoding="utf-8")).items():
        CONFIG[_k] = {**CONFIG.get(_k, {}), **_v} if isinstance(_v, dict) else _v
TOPIC = (CONFIG.get("notify") or {}).get("ntfy_topic")


def alert(title: str, msg: str) -> None:
    if not TOPIC:
        return
    try:
        req = urllib.request.Request(f"https://ntfy.sh/{TOPIC}", data=msg.encode(), method="POST",
                                     headers={"Title": title, "Priority": "high", "Tags": "zombie"})
        urllib.request.urlopen(req, timeout=20).read()
    except Exception:  # noqa: BLE001
        pass


def orchestrator_running() -> bool:
    ps = ("@(Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
          "Where-Object { $_.CommandLine -like '*orchestrator.py*' }).Count")
    out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout.strip()
    return out.isdigit() and int(out) > 0


def project_complete() -> bool:
    try:
        return "PROJECT COMPLETE" in EVENTS.read_text(encoding="utf-8", errors="replace")[-20000:]
    except OSError:
        return False


misses = 0
while True:
    if project_complete():
        alert("Zombie Siege: finished!", "M12 is complete and the team has stopped. Play builds/ZombieSiege.exe (v1.7.0).")
        break
    if (ROOT / "project" / "STOP").exists():
        break
    misses = 0 if orchestrator_running() else misses + 1
    if misses >= 2:  # down for two checks in a row (start.bat's own 60 s auto-restart didn't bring it back)
        subprocess.run(["explorer.exe", str(ROOT / "start.bat")])
        alert("Zombie Siege: orchestrator restarted", "It was not running, so the supervisor relaunched start.bat.")
        misses = 0
        time.sleep(300)
    time.sleep(120)
