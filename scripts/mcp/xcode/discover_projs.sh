#!/usr/bin/env bash
set -euo pipefail

ROOT=${1:-$(pwd)}

mapfile -t PROJS < <(find "$ROOT" -type d -name "*.xcodeproj" -maxdepth 4 2>/dev/null | sort)

printf '{"projects":['
first=1
for p in "${PROJS[@]}"; do
  [[ $first -eq 1 ]] || printf ','
  first=0
  printf '"%s"' "${p}"
done
printf ']}'

