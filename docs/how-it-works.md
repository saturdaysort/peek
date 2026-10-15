# How Peek works, and the traps found building it

Peek replaces a notification banner that opened Script Editor. Everything below was found by
inspection and live testing on 2026-10-15 (Claude Desktop 2.37337.1, Claude Code 2.1.295).
None of it is documented by Anthropic, so it is the first thing to re-check after a Claude
update.

## Why the old banner opened Script Editor

The banner came from the everything-claude-code plugin, not from Claude. Its `Stop` hook
(`stop:desktop-notify`, `scripts/hooks/desktop-notify.js`) runs
`osascript -e 'display notification ...'`. macOS attributes every notification posted by
`osascript` to Script Editor, so the banner shows Script Editor's icon and opens it on
click. There is no way to fix that from inside `osascript`.

Peek turns that hook off with the plugin's own switch, `ECC_DISABLED_HOOKS=stop:desktop-notify`,
in the `env` block of `~/.claude/settings.json`. The plugin itself is untouched and still
updates normally.

Peek doesn't depend on that plugin. `scripts/hooks.py install` adds the switch only when
`~/.claude/plugins/installed_plugins.json` lists `everything-claude-code` (from any
marketplace). Without it, only Peek's own hook entries are written. Install the plugin later
and the banner comes back until `install` is run again.

## How Peek knows which session pinged

Every process a Claude Desktop Code session starts, hooks included, inherits
`CLAUDE_CODE_HOST_SESSION_ID=local_<uuid>`. That is the Desktop's id for the session, not the
CLI's `session_id` from the hook JSON. Terminal `claude` sessions do not have it, and
`hook/peek-hook` exits quietly without it.

## Which events reach Peek

- **`Stop`:** a session finished its turn. The bubble shows the first prose line of
  `last_assistant_message`.
- **`Notification` with `notification_type` `permission_prompt` or `elicitation_dialog`:**
  the session is waiting on you. This includes Claude asking you a question with its
  question tool, which arrives as "Claude needs your permission to use AskUserQuestion".
- **Dropped:** `idle_prompt` (a repeat of a `Stop` already shown) and `auth_success`.

Hook entries added to `~/.claude/settings.json` were picked up by sessions that were already
open; no restart was needed. The `env` switch was verified in a new session.

## How a click opens the session

Claude Desktop's URL handler, inside `/Applications/Claude.app/Contents/Resources/app.asar`,
accepts `claude://code/continue?session=local_<uuid>`:

- If the session exists and isn't archived, Claude opens it. This was verified live: the
  click landed on the right session, and its `lastFocusedAt` updated.
- Otherwise it falls back to the Code home screen.

Claude validates the id with `^local_[A-Za-z0-9-]{1,64}$`. `DeepLink.swift` applies the same
rule, so nothing from the inbox can turn into an arbitrary URL.

To re-check after an update, search the bundle for the handler:

```bash
python3 -I -c "d=open('/Applications/Claude.app/Contents/Resources/app.asar','rb').read();i=d.find(b'code_continue');print(d[i-400:i+400].decode('utf8','replace'))"
```

## Where titles come from

Each session has a file at
`~/Library/Application Support/Claude/claude-code-sessions/<account>/<org>/local_<uuid>.json`.
It holds `title`, `isArchived`, `lastFocusedAt`, and more.

- There were 180 of these files, 24 MB in total, on the dev Mac. So the courtesy rule
  ("don't ping me about the session I'm looking at") reads only the 5 most recently modified.
- Switching to a session rewrites its file, so the focused session is always among those 5.
- If the layout changes, titles fall back to the project folder's name. Nothing breaks.

## The hook-to-app hand-off

`hook/peek-hook` writes `<epoch-ms>-<pid>.event` into
`~/Library/Application Support/Peek/inbox` (mode 700).

- It writes to a temp file and renames it, so Peek never reads half a file.
- Line 1 is the Desktop session id. The rest is the hook JSON, capped at 1 MB.
- Whatever stdin is left past the cap is drained, so Claude never writes into a closed pipe.
- Every path exits 0: a notification helper must never fail a Claude turn.

The inbox path is written in two places: `hook/peek-hook` and `Inbox.relativePath`.
`InboxTests.hookAndAppAgreeOnTheInboxPath` fails the build if they drift apart.

`scripts/hooks.py` writes `settings.json` with `ensure_ascii=False`. Python's default
escaped every em dash in the existing settings to `—`. The JSON still meant the same
thing, but it rewrote lines Peek has no business touching.

## Reading Peek's log

```bash
/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "dev.longbrook.peek"'
```

Two traps here, both silent:

- **`log` is shadowed in zsh.** zsh has a builtin called `log`, so plain `log show` fails
  with "too many arguments". Use the full path.
- **NSLog text is redacted.** On this macOS, NSLog text is stored as `<private>` in the
  unified log. Peek logs through `os.Logger` with public privacy (`Sources/Peek/Log.swift`)
  instead.

## Silent failures to know about

- **Peek isn't running:** events wait in the inbox. Anything over an hour old is dropped
  unread at the next launch, on purpose.
- **`~/Applications/Peek.app` is deleted but the hooks are still registered:** the guarded
  hook command exits 0 silently. `python3 -I scripts/hooks.py uninstall` removes the entries.
- **Open at login stops working:** it uses `SMAppService` with an ad-hoc signature. The log
  line `login item status N` shows its state: 1 is enabled; 2 means macOS wants approval in
  System Settings > General > Login Items.
- **Open at login points at a deleted copy:** `SMAppService.mainApp` registers whichever
  copy of Peek calls it, and Peek calls it at every launch. Opening `build/Peek.app` (from
  Finder, or `open build/Peek.app`) can register that copy as the login item, and the next
  `scripts/build.sh` deletes it. Only ever launch `~/Applications/Peek.app`;
  `scripts/install.sh` does that for you.
