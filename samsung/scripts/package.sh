#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tizen_root="${TIZEN_ROOT:-/Volumes/Galactus/tizen-studio}"
platforms_root="${PLATFORMS_ROOT:-/Users/luke/workspace/platforms}"

export PATH="$tizen_root/tools/ide/bin:$tizen_root/tools:$PATH"
export PYTHONPATH="$platforms_root/src:$platforms_root/tools:$platforms_root"

"$platforms_root/.venv/bin/python" -m platforms build \
  --project "$repo_root/samsung/tizen" \
  --platform tizen \
  --json
