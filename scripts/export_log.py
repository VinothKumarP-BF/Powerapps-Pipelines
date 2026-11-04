#!/usr/bin/env python3
"""Append one export log line, or publish that file to the export-logs branch.
 
Usage: python export_log.py start|step|solution-start|solution-export-ok|solution-unpack-ok|finish|fail|publish [message]
"""
 
import os
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
 
COMMANDS = (
    "start",
    "step",
    "solution-start",
    "solution-export-ok",
    "solution-unpack-ok",
    "finish",
    "fail",
)
IST = timezone(timedelta(hours=5, minutes=30))
 
 
def runner_temp():
    return Path(os.environ.get("RUNNER_TEMP", "/tmp"))
 
 
def path_file():
    return runner_temp() / "export-log-path.txt"
 
 
def ist_now():
    return datetime.now(timezone.utc).astimezone(IST)
 
 
def log_file():
    chosen = os.environ.get("EXPORT_LOG_FILE")
    if chosen:
        return Path(chosen)
    pointer = path_file()
    if pointer.is_file():
        return Path(pointer.read_text(encoding="utf-8").strip())
    now = ist_now()
    run_id = os.environ.get("GITHUB_RUN_ID", "local")
    dest = runner_temp() / "export-logs" / now.strftime("%Y-%m-%d") / f"{now.strftime('%H%M%S')}-{run_id}.log"
    dest.parent.mkdir(parents=True, exist_ok=True)
    pointer.write_text(str(dest) + "\n", encoding="utf-8")
    return dest
 
 
def append_line(kind, message):
    dest = log_file()
    dest.parent.mkdir(parents=True, exist_ok=True)
    utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    ist = ist_now().strftime("%Y-%m-%dT%H:%M:%S+0530")
    with dest.open("a", encoding="utf-8") as handle:
        handle.write(f"{utc} {ist} {kind} {message}\n")
 
 
def git(args, cwd=None, check=True):
    token = os.environ.get("GITHUB_TOKEN", "")
    command = ["git", "-c", f"http.extraheader=AUTHORIZATION: bearer {token}", *args]
    result = subprocess.run(command, cwd=cwd)
    if check and result.returncode != 0:
        print(f"git failed ({result.returncode}): {' '.join(args)}", file=sys.stderr)
        sys.exit(result.returncode)
    return result
 
 
def publish():
    pointer = path_file()
    if not pointer.is_file():
        return
    status = os.environ.get("JOB_STATUS", "")
    if status != "success":
        append_line("fail", status or "failed")
    local_file = Path(pointer.read_text(encoding="utf-8").strip())
    rel = local_file.relative_to(runner_temp()).as_posix()
    work = runner_temp() / "export-logs-repo"
    remote = f"https://github.com/{os.environ['GITHUB_REPOSITORY']}.git"
    if work.exists():
        shutil.rmtree(work)
    probe = git(["ls-remote", "--exit-code", "--heads", remote, "export-logs"], check=False)
    if probe.returncode == 0:
        git(["clone", "--branch", "export-logs", "--single-branch", "--depth", "1", remote, str(work)])
    elif probe.returncode == 2:
        work.mkdir(parents=True, exist_ok=True)
        git(["init", "-b", "export-logs", str(work)])
        git(["remote", "add", "origin", remote], cwd=work)
    else:
        sys.exit(probe.returncode)
    dest = work / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(local_file, dest)
    git(["config", "user.name", "github-actions"], cwd=work)
    git(["config", "user.email", "actions@github.com"], cwd=work)
    git(["add", "--", rel], cwd=work)
    git(["commit", "-m", f"Export log {rel}"], cwd=work)
    git(["push", "origin", "export-logs"], cwd=work)
 
 
def main(argv):
    if not argv:
        print("Missing log command", file=sys.stderr)
        return 1
    command, message = argv[0], " ".join(argv[1:])
    if command == "publish":
        publish()
        return 0
    if command not in COMMANDS:
        print(f"Unknown log command: {command}", file=sys.stderr)
        return 1
    append_line(command, message)
    return 0
 
 
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
