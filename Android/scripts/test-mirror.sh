#!/usr/bin/env bash
# The vault is exFAT (AppleDouble files break Gradle's snapshots): copy Android/ to APFS and run Gradle there.
# Usage: Android/scripts/test-mirror.sh [gradle args, default: test]
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
DST=/tmp/xpr/cyl-android
mkdir -p "$DST"
rsync -a --delete --exclude '._*' --exclude build --exclude .gradle --exclude .kotlin --exclude local.properties "$SRC"/ "$DST"/
cd "$DST"
exec ./scripts/gradle.sh "${@:-test}"
