#!/usr/bin/env bash
# Builds Tests/LifecycleTests with the library sources into a fresh simulator app and runs it.
# Usage: bash Tests/run-lifecycle-tests.sh [simulator UDID]
set -euo pipefail
cd "$(dirname "$0")/.."
UDID="${1:-${CYL_TEST_SIMULATOR:-}}"
if [ -z "$UDID" ]; then
  echo "Pass a simulator UDID (or set CYL_TEST_SIMULATOR)." >&2
  exit 2
fi
OUT="$(mktemp -d "${TMPDIR:-/tmp}/cyl-lifecycle-tests.XXXXXX")"
APP="$OUT/CYLLifecycleTests.app"
mkdir -p "$APP"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun --sdk iphonesimulator swiftc -Onone -g -D DEBUG -target "$(uname -m)-apple-ios15.0-simulator" -sdk "$SDK" \
  CYLDeallocBlockExecutor/*.swift Tests/LifecycleTests/main.swift -o "$APP/CYLLifecycleTests"
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.chenyilong.CYLLifecycleTests</string>
<key>CFBundleExecutable</key><string>CYLLifecycleTests</string>
<key>CFBundleName</key><string>CYLLifecycleTests</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>15.0</string>
<key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string></array>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
<key>UILaunchScreen</key><dict/>
<key>UIApplicationSceneManifest</key><dict>
<key>UIApplicationSupportsMultipleScenes</key><false/>
<key>UISceneConfigurations</key><dict><key>UIWindowSceneSessionRoleApplication</key><array><dict>
<key>UISceneConfigurationName</key><string>Default</string>
<key>UISceneDelegateClassName</key><string>CYLTestSceneDelegate</string>
</dict></array></dict></dict>
</dict></plist>
PLIST
codesign -s - "$APP" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
# Run 1: an exchange-style swizzle installed after the hooks. Run 2: installed before them.
xcrun simctl launch --console-pty --terminate-running-process "$UDID" com.chenyilong.CYLLifecycleTests 2>&1 | tee "$OUT/log1.txt"
xcrun simctl launch --console-pty --terminate-running-process "$UDID" com.chenyilong.CYLLifecycleTests -exchangeFirst 2>&1 | tee "$OUT/log2.txt"
grep -q "RESULT: PASS" "$OUT/log1.txt"
grep -q "RESULT: PASS" "$OUT/log2.txt"
echo "ALL RUNS PASSED"
