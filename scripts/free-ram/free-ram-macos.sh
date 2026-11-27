#!/usr/bin/env bash
# Free RAM on macOS before simulator debugging: quit heavy apps and daemons, restart Finder,
# shut down idle iOS simulators. Dry run by default; pass --yes to act.
#
# Usage: scripts/free-ram/free-ram-macos.sh [--yes] [--keep <UDID>]... [--max-sims 2] [--with-xcode]
# Rules: never `simctl shutdown all`; a simulator that a running xcodebuild/xctest names stays booted.
set -u

APPLY=0; MAX_SIMS=2; WITH_XCODE=0; KEEP=()
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) APPLY=1 ;;
    --keep) shift; KEEP+=("$1") ;;
    --max-sims) shift; MAX_SIMS="$1" ;;
    --with-xcode) WITH_XCODE=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

run() { if [ "$APPLY" = 1 ]; then echo "+ $*"; "$@" 2>&1 | head -3; else echo "[dry-run] $*"; fi; }

# Apps to quit (SIGTERM, so each app can save its state). Missing apps are skipped silently.
APPS=("WeChat DevTools" "wechatwebdevtools" "DevEco-Studio" "Obsidian" "Android Studio"
      "Google Chrome" "TextExpander" "CleanMyMac X" "bionic" "opencode" "minimax")
[ "$WITH_XCODE" = 1 ] && APPS+=("Xcode")
for app in "${APPS[@]}"; do
  if pgrep -xi "$app" >/dev/null 2>&1; then run killall "$app"; fi
done

# Background services and emulators.
pgrep -f "qemu-system|emulator/emulator" >/dev/null 2>&1 && run pkill -f "qemu-system|emulator/emulator"
pgrep -f "Huawei.*Emulator|hmos.*emulator" >/dev/null 2>&1 && run pkill -f "Huawei.*Emulator|hmos.*emulator"
pgrep -x watchman >/dev/null 2>&1 && run watchman shutdown-server
pgrep -f GradleDaemon >/dev/null 2>&1 && run pkill -f GradleDaemon

# Restart Finder (this also closes every Finder window).
run killall Finder

# Simulators: keep those a running build/test names, plus --keep UDIDs, up to MAX_SIMS; shut down the rest by UDID.
BUSY="$(ps -axo args | command grep -E 'xcodebuild|xctest' | command grep -v grep)"
kept=0
while IFS= read -r line; do
  udid="$(echo "$line" | command grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}')"
  name="$(echo "$line" | sed -E 's/^ *(.*) \([0-9A-F-]{36}\) \(Booted\).*/\1/')"
  [ -z "$udid" ] && continue
  keep=0
  echo "$BUSY" | command grep -qF "$udid" && keep=1
  echo "$BUSY" | command grep -qF "$name" && keep=1
  for k in ${KEEP[@]+"${KEEP[@]}"}; do [ "$k" = "$udid" ] && keep=1; done
  if [ "$keep" = 1 ] && [ "$kept" -lt "$MAX_SIMS" ]; then
    echo "keep simulator: $name ($udid)"; kept=$((kept+1))
  else
    run xcrun simctl shutdown "$udid"
  fi
done < <(xcrun simctl list devices | command grep '(Booted)')

echo "Booted simulators now:"; xcrun simctl list devices | command grep '(Booted)' || echo "  none"
echo "Next: scripts/free-ram/macos-display.sh (brightness, mirroring, iTerm2), then message the other sessions."
