#!/usr/bin/env bash
# The vault is exFAT: copy HarmonyOS/ to APFS and build the HAR there with the hvigor in DevEco-Studio.
# Usage: HarmonyOS/scripts/build-har.sh   (unsigned HAR, no emulator)
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
DST=/tmp/xpr/cyl-harmony
D=/Applications/DevEco-Studio.app/Contents
mkdir -p "$DST"
rsync -a --delete --exclude '._*' --exclude node_modules --exclude oh_modules --exclude build --exclude .hvigor "$SRC"/ "$DST"/
cd "$DST"
export DEVECO_SDK_HOME=$D/sdk NODE_HOME=$D/tools/node PATH=$D/tools/node/bin:$D/tools/ohpm/bin:$D/tools/hvigor/bin:$PATH
exec hvigorw assembleHar --mode module -p module=cyldeallocblockexecutor@default -p product=default --no-daemon
