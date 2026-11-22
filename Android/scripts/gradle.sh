#!/usr/bin/env bash
# Runs Gradle with the tools already on this machine: Android Studio's JDK and
# the Gradle distribution cached in ~/.gradle. Usage: Android/scripts/gradle.sh test
set -euo pipefail
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
GRADLE="$(ls -d "$HOME"/.gradle/wrapper/dists/gradle-9.9.2-bin/*/gradle-9.9.2/bin/gradle | head -1)"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
exec "$GRADLE" "$@"
