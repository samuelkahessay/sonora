#!/usr/bin/env bash
set -euo pipefail

# Usage: build_sim.sh <projectPath.xcodeproj> <scheme> <simulatorName>
if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <projectPath.xcodeproj> <scheme> <simulatorName>" >&2
  exit 1
fi

PROJ="$1"; SCHEME="$2"; SIM="$3"

DEST="platform=iOS Simulator,name=${SIM}"

set -x
xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination "$DEST" -configuration Debug build | xcbeautify || true
set +x

echo "{\"status\":\"ok\"}"

