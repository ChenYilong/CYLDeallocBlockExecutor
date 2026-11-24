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
# CYL_TEST_CONFIGURATION=release builds like a consumer's Release build (-O, no DEBUG).
if [ "${CYL_TEST_CONFIGURATION:-debug}" = "release" ]; then FLAGS=(-O); else FLAGS=(-Onone -g -D DEBUG); fi
xcrun --sdk iphonesimulator swiftc "${FLAGS[@]}" -target "$(uname -m)-apple-ios15.0-simulator" -sdk "$SDK" \
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
# A launch whose log has no RESULT line means the process died mid-test (CI once showed run 1 ending without a crash line):
# print the end of that log and the newest crash report of the test app, then fail.
report_missing_result() {
  local log="$1" name="$2"
  grep -q "RESULT:" "$log" && return 0
  echo "ERROR: $name printed no RESULT line: the test process died. Last 20 lines of its log:" >&2
  tail -n 20 "$log" >&2
  local crash_dir report
  for crash_dir in "$HOME/Library/Logs/DiagnosticReports" "$HOME/Library/Logs/CoreSimulator/$UDID"; do
    [ -d "$crash_dir" ] || continue
    report="$(find "$crash_dir" -type f \( -name 'CYLLifecycleTests*.ips' -o -name 'CYLLifecycleTests*.crash' \) -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n 1 || true)"
    if [ -n "$report" ]; then
      echo "Newest crash report: $report (first 60 lines)" >&2
      head -n 60 "$report" >&2
      return 1
    fi
  done
  echo "No CYLLifecycleTests crash report found under ~/Library/Logs/DiagnosticReports or CoreSimulator." >&2
  return 1
}
missing=0
report_missing_result "$OUT/log1.txt" "run 1" || missing=1
report_missing_result "$OUT/log2.txt" "run 2 (-exchangeFirst)" || missing=1
[ "$missing" -eq 0 ] || exit 1
grep -q "RESULT: PASS" "$OUT/log1.txt"
grep -q "RESULT: PASS" "$OUT/log2.txt"
echo "ALL RUNS PASSED"
