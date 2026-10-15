# Peek: a desktop pet for Claude Code notifications

Date: 2026-10-15
Status: implemented 2026-10-15

## Goal

Replace the Script Editor notification banner with a small pixel-art pet in the
bottom-right corner of the screen. When a Claude Desktop Code session finishes or
needs attention, the pet scuttles in with a speech bubble. Clicking it opens
**that exact session** in Claude. When the message is handled, it scuttles off.

Success looks like:

1. A finished session produces a bubble naming the session, within about a second.
2. Clicking the bubble lands on that session in Claude, not on Script Editor and
   not on whichever session happened to be open.
3. Nothing is lost if you look away: unread messages wait in a peek.
4. The Script Editor banner no longer appears.

## Background (findings, 2026-10-15)

These were verified on this Mac before the design was drawn. They are the reason
the design looks the way it does, and none of them are documented by Anthropic.

- **The banner comes from a plugin, not from Claude Desktop.** The
  everything-claude-code plugin (v1.9.0) registers a `Stop` hook with id
  `stop:desktop-notify` (`scripts/hooks/desktop-notify.js`). It calls
  `osascript -e 'display notification ...'`. macOS attributes any notification
  posted by `osascript` to Script Editor, which is why the banner shows the
  Script Editor icon and why clicking it opens Script Editor. Nothing about that
  can be fixed from inside `osascript`.
- **The plugin hook can be turned off without editing the plugin.** Its runner
  reads `ECC_DISABLED_HOOKS` (comma-separated hook ids) in
  `scripts/lib/hook-flags.js`.
- **Hooks know which Desktop session they belong to.** Processes started by a
  Claude Desktop Code session inherit `CLAUDE_CODE_HOST_SESSION_ID=local_<uuid>`
  (the Desktop's session id, distinct from the CLI's `session_id`). Terminal
  `claude` sessions do not have it.
- **Claude Desktop can deep-link to a session.** Its URL handler (app 2.37337.1,
  `app.asar`) accepts `claude://code/continue?session=<id>` where `<id>` matches
  `^local_[A-Za-z0-9-]{1,64}$`. It looks the id up among non-archived sessions
  and navigates there. If the id is unknown or archived, it falls back to the
  Code home screen. `session=last` opens the most recent session.
- **Session titles are on disk.** Each Desktop session has a JSON file at
  `~/Library/Application Support/Claude/claude-code-sessions/<account>/<org>/local_<uuid>.json`
  with `title`, `cwd`, `isArchived`, `lastFocusedAt`, and `lastActivityAt`.

## Behavior

### Character and look

- **Character:** "Block buddy", an original Clawd-like sprite: a square body,
  side arms, two eyes, and four legs. It is drawn in code from a pixel map, with no
  image files. Grid is 16 x 9 sprite pixels at 5 pt each (80 x 45 pt). That is 10
  device pixels per sprite pixel on Retina, so it stays crisp.
- **Colors:** body clay `#D97757`, eyes and outline ink `#1F1A17`, bubble paper
  `#FFFDF8`. One source of truth: the sprite file.
- **Sprite map** (`o` = clay, `k` = ink, `.` = clear):

  ```
  ..oooooooooooo..
  ..ookkooookkoo..
  ..ookkooookkoo..
  oooooooooooooooo
  oooooooooooooooo
  ..oooooooooooo..
  ..oooooooooooo..
  ..o.o......o.o..   legs, frame A (also the standing pose)
  ..o.o......o.o..
  ```

  Leg frame B, which alternates with A every 130 ms while walking:

  ```
  ...o.o....o.o...
  ...o.o....o.o...
  ```

  Blink: every ~2.6 s, eyes (`k`) render as body (`o`) for 140 ms.
- **Font:** Press Start 2P (SIL Open Font License, bundled with its license file).
  It is drawn at 8 pt with a 12 pt line height. The font is built on an 8 px grid, so
  8 pt maps to exactly 2 device pixels per font pixel on Retina.
- **Bubble:** paper fill, 3 pt ink border, notched (pixel-stepped) corners, and a
  pixel-stair tail pointing down-right at the pet. Max width 248 pt, about 31
  characters per line.
  - Line 1: session title, dimmed (60 percent ink), one line, truncated with "...".
  - Lines 2 to 4: the message, at most 3 lines, truncated with "...".
  - "Needs you" messages prefix line 1 with a blinking `!`.

### Placement

- Bottom-right of the main display (the one with the menu bar), using the
  visible frame so it sits above the Dock. It is inset 12 pt from the right.
  Its feet stand on the bottom edge of the visible frame (inset 0), so ducking
  reads as sinking behind that edge. The window clips everything past the
  right and bottom edges.
- Floats above normal windows (status-bar level), on every Space, and over
  full-screen apps.
- Re-anchors when displays or the Dock change.
- When there are no messages it is fully off screen and its window is ordered
  out, so it never intercepts a click.

### Message kinds

| Kind      | Source hook event | Entrance                                         |
| --------- | ----------------- | ------------------------------------------------ |
| Done      | `Stop`            | Scuttle in over 1.1 s, one hop, bubble pops      |
| Needs you | `Notification`    | Scuttle in over 0.7 s, two bounces, blinking `!` |

Message text:

- *Done:* the first non-empty line of `last_assistant_message`.
- *Needs you:* the hook's `message`.

Either way, the text is cleaned before it's fitted to 3 lines:

- Code fences and their contents, table rows, and horizontal rules are skipped.
- Markdown is stripped: `**`, `` ` ``, leading `#`, list markers, and
  `[text](url)` becomes `text`.
- Whitespace is collapsed.

Empty text falls back to "Done" or "Needs you".

`Notification` events of type `idle_prompt` (a repeat of `Stop`) and
`auth_success` are dropped.

### States and timing

```
hidden --arrival--> entering --> showing --10 s, not hovered--> peeking
showing --click--> (open session) --> leaving --> hidden          (queue empty)
showing --click--> (open session) --> hop --> showing next        (queue not empty)
peeking --click--> showing (oldest message)
peeking --arrival--> showing (the new message)
```

- **Showing:** the bubble types its text on (about 1.5 s total regardless of
  length) and stays 10 s. The timer pauses while the pointer is over the pet or
  bubble.
- **Peeking:** over 420 ms the pet sinks so only its top 3 sprite rows (the eyes)
  show above the screen edge. A count badge shows how many messages are unread.
- **Leaving:** over 900 ms it scuttles right, off screen, then the window is
  ordered out.
- **Arrival while a bubble is showing:** the new message is queued and the badge
  increments. The current bubble is not interrupted.
- **Badge:** while the bubble is out it shows the *others* waiting (hidden when
  0). While peeking it shows the total.
- Motion is stepped (`steps()`-style), not smoothly eased, to read as pixel art.

### Queue

- Oldest first. Unread messages stay queued until clicked or dismissed.
- One message per session: a newer message from the same session replaces the
  older one in place.
- Capped at 20; past that the oldest is dropped.
- Scroll over the bubble to flip through the queue without opening anything.
- In memory only. Inbox files are deleted as soon as they are ingested.

### Interaction

- **Click the bubble or pet:** open the session (see Deep link) and remove the
  message.
- **Right-click** opens a menu:
  - Dismiss (removes the current message)
  - Dismiss all
  - Quiet for 1 hour (messages still queue silently; when quiet ends, if
    anything is unread, the pet appears in peek)
  - Sound (toggle, off by default): a short generated 8-bit chirp on arrival
  - Open at login (toggle, on by default)
  - Quit
- **Opening Peek.app while it is running** (double-click, Spotlight) makes the pet
  scuttle in and say "Nothing new" (or show the queue, if there is one). This is
  how the menu is reachable when the pet is hidden. There is no Dock icon and no
  menu bar icon.

### Courtesy rule (best-effort)

A message is dropped rather than shown when Claude is the frontmost app and the
message's session has the most recent `lastFocusedAt` among the 5 most recently
modified session files. There are 180 files totaling 24 MB on this Mac, so it
can't read them all on every event. This depends on `lastFocusedAt` updating
when you switch to a session. It gets verified during build, and the rule is cut
if it can't be made reliable.

## Architecture

```
Claude Desktop session
  └─ Stop / Notification hook
       └─ peek-hook (sh) ──writes──> ~/Library/Application Support/Peek/inbox/<ts>-<pid>.event
                                          │
Peek.app  <──── watches (FSEvents/DispatchSource) ───┘
  ├─ PeekCore (pure logic, unit tested)
  │    EventParser · MessageQueue · TextTrimmer · DeepLink · SessionDirectory
  └─ App (AppKit)
       PetPanel · PetView (sprite + bubble) · Choreographer (state machine + timing)
       InboxWatcher · Chirp · LoginItem
  └─ click ──> NSWorkspace.open(claude://code/continue?session=local_...)
```

### peek-hook (zsh)

Shipped inside the app at `Peek.app/Contents/Resources/peek-hook`. It's zsh
rather than plain sh because zsh's `EPOCHREALTIME` gives millisecond file names
without spawning another process.

1. Exit 0 immediately if `CLAUDE_CODE_HOST_SESSION_ID` is empty (not a Desktop
   session).
2. `mkdir -p` the inbox with mode 700.
3. Write the envelope to a dot-prefixed temp file, then `mv` it to
   `<epoch-ms>-<pid>.event`. The rename is atomic, so Peek never reads a partial
   file.
4. Always exit 0. It never blocks or slows Claude; the work is a few
   milliseconds.

**Envelope format:** line 1 is the host session id. The rest is the hook's stdin
JSON, verbatim, capped at 1 MB; the remainder of stdin is drained and discarded.
If a payload is cut by the cap, the parser salvages the event name and `cwd`
from the first 4 KB and shows the default text.

### Hook registration (`~/.claude/settings.json`)

```json
{
  "env": { "ECC_DISABLED_HOOKS": "stop:desktop-notify" },
  "hooks": {
    "Stop":         [{ "hooks": [{ "type": "command", "timeout": 5, "command": "<guarded call>" }] }],
    "Notification": [{ "matcher": "permission_prompt|elicitation_dialog",
                       "hooks": [{ "type": "command", "timeout": 5, "command": "<guarded call>" }] }]
  }
}
```

`<guarded call>` runs `~/Applications/Peek.app/Contents/Resources/peek-hook` if it
exists and always exits 0. Uninstalling Peek therefore never produces hook
errors. The existing file is backed up before editing, and the edit merges into
whatever is already there.

### PeekCore (no AppKit; covered by `swift test`)

- **EventParser:** envelope to `PeekEvent { hostSessionId, kind (done | needsYou),
  text, cwd, receivedAt }`, or `nil` for malformed input, unknown events, or an
  invalid id.
- **TextTrimmer:** Markdown stripping and the first-line rule. Line fitting
  happens in the view, because it depends on the font.
- **MessageQueue:** FIFO, per-session replacement, cap, and current-index
  navigation for scrolling.
- **DeepLink:** `url(for hostSessionId) -> URL?`. It returns `nil` unless the id
  matches `^local_[A-Za-z0-9-]{1,64}$`, so a crafted inbox file can at worst show
  a fake bubble and can never open an arbitrary URL.
- **SessionDirectory:** finds the session JSON under an injectable root and returns
  `title`, `isArchived`, `lastFocusedAt`. Title falls back to the last path
  component of `cwd`, then to "Claude".

### App (AppKit)

- **PetPanel:** a borderless, non-activating `NSPanel` with clear background and
  no shadow. Status-bar level. Collection behavior: all Spaces, full-screen
  auxiliary, stationary, ignores cycle. It is sized tightly to the pet plus bubble,
  so transparent areas never block clicks.
- **PetView:** draws the sprite and bubble with Core Graphics on integer point
  coordinates, with antialiasing off for the sprite.
- **Choreographer:** owns the state machine above and all timings (one constants
  block). It runs on a single 60 Hz timer that advances frames and positions in
  steps.
- **InboxWatcher:** watches the inbox directory. It also scans on launch: files
  older than 1 hour are deleted unread, newer ones are ingested.
- **Chirp:** a ~120 ms square-wave blip generated at runtime with
  `AVAudioEngine`.
- **LoginItem:** `SMAppService.mainApp`. If that refuses an ad-hoc-signed app, a
  LaunchAgent plist in `~/Library/LaunchAgents` is the fallback.
- **Settings:** sound, open-at-login, and quiet-until live in `UserDefaults`.

## Build and install

- A Swift package (Swift 6.4 toolchain, macOS 14+ target) with targets `PeekCore`,
  `Peek`, and `PeekCoreTests`. There is no Xcode project file.
- `scripts/build.sh`:
  1. `swift build -c release`
  2. Assemble `build/Peek.app` (Info.plist with `LSUIElement`, bundle id
     `dev.longbrook.peek`, the font and its license, `peek-hook`).
  3. Ad-hoc sign it.
- `scripts/install.sh`: builds, replaces `~/Applications/Peek.app`, and relaunches
  it.
- `scripts/hooks.py install`: backs up and merges the `settings.json` changes
  above. `scripts/hooks.py uninstall` reverses exactly those. It uses only the
  Python standard library and is tested from `swift test`.
- The font is downloaded once from the google/fonts repository with your
  approval and committed under `Resources/`.

## Error handling

| Situation                                       | Result                                                                 |
| ----------------------------------------------- | ---------------------------------------------------------------------- |
| Claude not running when clicked                 | The deep link launches Claude, then navigates                          |
| Session archived or deleted                     | Claude shows the Code home screen                                      |
| Claude update changes the URL format            | Click still brings Claude forward; documented as the first thing to check |
| Session files move or change shape              | Title falls back to the folder name                                    |
| Peek not running                                | Events wait in the inbox; anything under 1 hour old shows on launch    |
| Malformed or hostile inbox file                 | Ignored and deleted; never turned into a URL                           |
| Burst of events                                 | Per-session replacement plus the 20-message cap                        |
| Peek uninstalled but hooks still registered     | The guarded command exits 0 silently                                   |

## Testing

**Unit (`swift test`)**, using fixtures for real `Stop` and `Notification`
payloads captured from this Mac:

- Parser: done, needs-you, malformed JSON, missing id, invalid id, unknown event.
- Trimmer: Markdown stripping, first-line rule, empty fallback.
- Queue: FIFO, per-session replacement, cap, navigation.
- Deep link: valid id produces the exact URL; anything else produces `nil`.
- Session directory: title found, archived flag, fallback chain, against a temp
  directory.

**Live, on this Mac** (confirmed by screenshot and by reading the inbox, not by
eye):

1. A real Desktop session finishes and the pet appears bottom-right with that
   session's title.
2. Clicking it navigates Claude to that session. This is tested from a
   *different* session so the navigation is provable.
3. A permission prompt produces a "needs you" message. If the `Notification`
   hook does not fire in Desktop sessions, this is reported and the alternative
   (`PermissionRequest` hook) is evaluated before anything is changed.
4. The `ECC_DISABLED_HOOKS` entry reaches the plugin hook in Desktop sessions and
   the Script Editor banner stops.
5. Peek quit, a session finishes, Peek relaunched: the message appears.
6. Open at login survives a logout/login.

## Docs

- `docs/how-it-works.md` records the findings above: why `osascript` shows as
  Script Editor, where the session id comes from, the deep-link format and how it
  was found, and that the URL handler and session files are undocumented and are
  the first thing to check after a Claude update.
- `README.md` covers install, uninstall, and what each script does.

## Out of scope

- Terminal `claude` sessions (no Desktop session id, no Desktop window to open).
- Cowork sessions, claude.ai chat, other machines.
- Changing Claude Desktop's own built-in notifications. They are left as they
  are; turn them off in Claude's settings if Peek makes them redundant.
- Customizing the character.

## Risks to verify first

1. The `Notification` hook fires in Desktop sessions.
2. `env` from `~/.claude/settings.json` reaches plugin hook processes in Desktop
   sessions.
3. `lastFocusedAt` tracks the session on screen (courtesy rule).
4. `SMAppService` accepts an ad-hoc-signed app in `~/Applications`.
5. The deep link navigates between sessions live, not just on paper.
