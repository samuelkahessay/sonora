#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <projectPath.xcodeproj>" >&2
  exit 1
fi

PROJ="$1"

SCHEMES=$(xcodebuild -list -project "$PROJ" 2>/dev/null | awk '/Schemes:/{flag=1;next}/Targets:/{flag=0}flag' | sed 's/^\s\+//; s/\r$//; /^$/d')

printf '{"schemes":['
first=1
while IFS= read -r s; do
  [[ -z "$s" ]] && continue
  [[ $first -eq 1 ]] || printf ','
  first=0
  printf '"%s"' "$s"
done <<< "$SCHEMES"
printf ']}'

