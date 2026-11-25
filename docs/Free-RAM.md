# Free RAM before simulator debugging

Scripts that quit heavy apps, shut down idle simulators and quiet the displays, so a simulator run has memory to spare.
Run them by hand. Every script is a **dry run unless you pass `--yes`**, so read the output first.

## macOS

Scripts live in [`scripts/free-ram/`](../scripts/free-ram/):

| Script | What it does |
| :-- | :-- |
| [`free-ram-macos.sh`](../scripts/free-ram/free-ram-macos.sh) | Quits WeChat DevTools, DevEco Studio, Obsidian, Android Studio, Chrome, TextExpander, CleanMyMac, bionic, opencode, minimax; stops emulators (Android, HarmonyOS), watchman and Gradle daemons; restarts Finder (closes all its windows); shuts down idle simulators |
| [`macos-display.sh`](../scripts/free-ram/macos-display.sh) | Dims displays, shows how to mirror two displays, reduces transparency, hides iTerm2 (it keeps running) |

### Run it

1. Check that no session is debugging on a simulator (ask in the session list). A simulator that a running `xcodebuild` / `xctest` names is kept automatically.
2. From the repository root, preview: `bash scripts/free-ram/free-ram-macos.sh`
3. Apply: `bash scripts/free-ram/free-ram-macos.sh --yes`
4. Display part, from a normal Terminal (macOS asks for Automation permission): `bash scripts/free-ram/macos-display.sh --yes`
5. Tell the other sessions (Mac and Windows) that the simulators were restarted, so a session that waited can start its simulator debugging again.

### Options of `free-ram-macos.sh`

| Option | Meaning |
| :-- | :-- |
| `--yes` | Act (default is a dry run) |
| `--keep <UDID>` | Keep this simulator booted (repeatable) |
| `--max-sims <n>` | Keep at most `n` simulators booted (default 2) |
| `--with-xcode` | Also quit the Xcode app (off by default; builds in progress would die) |

### Rules and limits

- Never `xcrun simctl shutdown all`: the Mac is shared; scripts shut down by UDID only.
- Apps get a normal quit signal (`killall`), so they can save state. Unsaved work in a quit app is your responsibility.
- Brightness needs `brew install brightness`; mirroring needs `brew install displayplacer` or System Settings > Displays. Without them the script prints the manual step.
- `reduceTransparency` may need a logout to apply fully.
- iTerm2 is hidden, not quit: running sessions (including Claude sessions) continue.
- Messaging other sessions is not scripted; do it in Claude Code (`SendMessage`).

## Windows

Not written yet. The Windows owner adds `scripts/free-ram/free-ram-windows.ps1` and fills this section (emulators, Gradle daemons, DevEco, WeChat DevTools).
