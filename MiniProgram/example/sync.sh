#!/usr/bin/env bash
# Copies the library (MiniProgram/*.js) into the project: a mini program cannot require files outside its root.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p miniprogram/cyl
for f in index registry center controller log types; do cp "../$f.js" "miniprogram/cyl/$f.js"; done
echo "synced MiniProgram/*.js into example/miniprogram/cyl"
