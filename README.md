# Peek

A small pixel pet that pops out of the bottom-right corner of your screen when a Claude
Desktop Code session finishes or needs you. Click its speech bubble to jump straight to that
session.

- Messages queue oldest first, one per session. Scroll over the bubble to flip through them.
- After 10 seconds the pet ducks so only its eyes peek over the edge, with a count of
  unread messages. Click the peek to bring them back.
- Right-click for Dismiss, Dismiss all, Quiet for 1 hour, Sound, Open at login, and Quit Peek.
- Open Peek from Finder or Spotlight while it's running to call the pet out.
- It stays quiet about the session Claude is already showing you.

## Install

```bash
scripts/install.sh
```

```bash
python3 -I scripts/hooks.py install
```

The first command builds `Peek.app`, installs it to `~/Applications`, and launches it.

The second registers Peek's hooks in `~/.claude/settings.json` and turns off the
everything-claude-code plugin's Script Editor banner. It writes a backup of that file first.

## Uninstall

```bash
python3 -I scripts/hooks.py uninstall
```

```bash
pkill -x Peek
```

```bash
rm -rf ~/Applications/Peek.app
```

## Develop

```bash
swift test
```

All logic lives in `Sources/PeekCore` and is unit tested. `Sources/Peek` is the AppKit
layer. The design is in `docs/superpowers/specs/2026-10-15-peek-design.md`, and the traps
are in `docs/how-it-works.md`.

## Troubleshooting

Read Peek's log. Use the full path: in zsh, `log` is a different builtin.

```bash
/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "dev.longbrook.peek"'
```

See whether events are reaching the inbox:

```bash
ls -la "$HOME/Library/Application Support/Peek/inbox"
```

- **Nothing shows up:** check whether events reach the inbox, then look for
  `received N event(s)` in the log.
- **A message was skipped:** a `skipped event for the focused session` line means Claude was
  already showing that session.
- **Clicking opens the Code home screen instead of a session:** the session was archived, or
  Claude changed its URL format (see `docs/how-it-works.md`).

The font is Press Start 2P by CodeMan38, under the SIL Open Font License (`Resources/OFL.txt`).
