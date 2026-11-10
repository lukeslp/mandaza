#!/usr/bin/env bash
set -euo pipefail

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
# The "platforms" packaging tool lives outside this repository.
platforms_root="${PLATFORMS_ROOT:-$HOME/workspace/platforms}"

export PATH="$tizen_root/tools/ide/bin:$tizen_root/tools:$PATH"
export PYTHONPATH="$platforms_root/src:$platforms_root/tools:$platforms_root"

"$platforms_root/.venv/bin/python" -m platforms build \
  --project "$repo_root/samsung/tizen" \
  --platform tizen \
  --json
