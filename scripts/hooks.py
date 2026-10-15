#!/usr/bin/env python3
"""Add or remove Peek's entries in Claude Code's ~/.claude/settings.json.

install   registers Peek's hook for Stop and Notification (permission_prompt and
          elicitation_dialog), and turns off the everything-claude-code plugin's
          osascript banner (the one macOS shows as Script Editor) through its
          ECC_DISABLED_HOOKS switch. The plugin itself is not touched.
uninstall removes exactly those entries.

Before any change, a copy of the file is written next to it as
settings.json.peek-backup-<timestamp>. Run with python3 -I (standard library only).
"""
import argparse
import json
import os
import shutil
import time

HOOK = "$HOME/Applications/Peek.app/Contents/Resources/peek-hook"
# Guarded so that a missing Peek.app never shows up as a hook error in Claude.
COMMAND = f'h="{HOOK}"; [ -x "$h" ] && "$h"; exit 0'
MARKER = "Peek.app/Contents/Resources/peek-hook"
ECC_ID = "stop:desktop-notify"
EVENTS = {"Stop": None, "Notification": "permission_prompt|elicitation_dialog"}


def load(path):
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        text = f.read()
    return json.loads(text) if text.strip() else {}


def save(path, data):
    if os.path.exists(path):
        shutil.copy2(path, f"{path}.peek-backup-{time.strftime('%Y%m%d-%H%M%S')}")
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = f"{path}.peek-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        # ensure_ascii=False keeps characters like em dashes as written, so the only lines
        # that change in the user's file are the ones Peek adds or removes.
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    if os.path.exists(path):
        # The temp file gets the umask's mode; a settings file kept at 600 should stay 600.
        shutil.copymode(path, tmp)
    os.replace(tmp, path)


def is_ours(group):
    return any(MARKER in h.get("command", "") for h in group.get("hooks", []))


def ecc_ids(env):
    return [i.strip() for i in env.get("ECC_DISABLED_HOOKS", "").split(",") if i.strip()]


def install(data):
    hooks = data.setdefault("hooks", {})
    for event, matcher in EVENTS.items():
        groups = hooks.setdefault(event, [])
        if not any(is_ours(g) for g in groups):
            group = {"hooks": [{"type": "command", "command": COMMAND, "timeout": 5}]}
            if matcher:
                group["matcher"] = matcher
            groups.append(group)
    env = data.setdefault("env", {})
    ids = ecc_ids(env)
    if ECC_ID not in ids:
        ids.append(ECC_ID)
    env["ECC_DISABLED_HOOKS"] = ",".join(ids)
    return data


def uninstall(data):
    hooks = data.get("hooks", {})
    for event in EVENTS:
        kept = [g for g in hooks.get(event, []) if not is_ours(g)]
        if kept:
            hooks[event] = kept
        else:
            hooks.pop(event, None)
    if "hooks" in data and not data["hooks"]:
        del data["hooks"]
    env = data.get("env", {})
    ids = [i for i in ecc_ids(env) if i != ECC_ID]
    if ids:
        env["ECC_DISABLED_HOOKS"] = ",".join(ids)
    else:
        env.pop("ECC_DISABLED_HOOKS", None)
    if "env" in data and not data["env"]:
        del data["env"]
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=["install", "uninstall"])
    parser.add_argument("--settings", default=os.path.expanduser("~/.claude/settings.json"))
    args = parser.parse_args()
    before = load(args.settings)
    after = (install if args.action == "install" else uninstall)(json.loads(json.dumps(before)))
    if after == before:
        print(f"{args.action}: nothing to change in {args.settings}")
        return
    save(args.settings, after)
    print(f"{args.action}: updated {args.settings} (backup written next to it)")


if __name__ == "__main__":
    main()
