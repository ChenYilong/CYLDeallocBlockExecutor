#!/usr/bin/env bash
# Display part of "free RAM": dim screens, mirror displays, reduce transparency, hide iTerm2 (it keeps running).
# Run it from a normal Terminal (osascript needs Automation permission). Dry run by default; pass --yes to act.
#
# Usage: scripts/free-ram/macos-display.sh [--yes] [--brightness 0.02]
# Optional tools: `brew install brightness displayplacer`.
set -u
APPLY=0; LEVEL=0.02
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) APPLY=1 ;;
    --brightness) shift; LEVEL="$1" ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
run() { if [ "$APPLY" = 1 ]; then echo "+ $*"; "$@"; else echo "[dry-run] $*"; fi; }

# 1. Brightness on every display.
if command -v brightness >/dev/null; then run brightness -l >/dev/null; for i in 0 1 2; do run brightness -d "$i" "$LEVEL"; done
else echo "skip brightness: install it (brew install brightness) or use the brightness keys / System Settings > Displays"; fi

# 2. Mirror displays: list first, then copy the printed command, mirroring the second id to the first.
if command -v displayplacer >/dev/null; then displayplacer list | command grep -E "Persistent screen id|Resolution"
  echo "Mirror: displayplacer \"id:<MAIN> res:<WxH> degree:0 origin:(0,0)\" \"id:<SECOND>+<MAIN> res:<WxH>\""
else echo "skip mirroring: System Settings > Displays > (+) next to the second display > Mirror for <main display>"; fi

# 3. Reduce transparency (may need a logout to apply fully).
run defaults write com.apple.universalaccess reduceTransparency -bool true

# 4. Hide iTerm2 (every window), process stays alive.
run osascript -e 'tell application "System Events" to set visible of process "iTerm2" to false'
