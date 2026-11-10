#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <samsung-tv-ip>" >&2
  exit 2
fi

tv_ip="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Tizen Studio lives outside this repository. TIZEN_ROOT overrides the lookup.
if [[ -z "${TIZEN_ROOT:-}" ]]; then
  if [[ -d "$HOME/tizen-studio" ]]; then
    TIZEN_ROOT="$HOME/tizen-studio"
  else
    TIZEN_ROOT="/Volumes/Galactus/tizen-studio"
  fi
fi
tizen_root="$TIZEN_ROOT"
sdb="$tizen_root/tools/sdb"
tizen="$tizen_root/tools/ide/bin/tizen"
widget="$(find "$repo_root/samsung/tizen/dist" -type f -name '*.wgt' -print -quit)"

if [[ -z "$widget" ]]; then
  echo "No widget found. Run samsung/scripts/package.sh first." >&2
  exit 1
fi

"$sdb" connect "$tv_ip:26101"
"$tizen" install -n "$widget" -s "$tv_ip:26101"
"$tizen" run -p MandazaTV1.MandazaTV -s "$tv_ip:26101"

echo "Installed and launched $widget on $tv_ip"
