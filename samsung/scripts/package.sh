#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tizen_root="${TIZEN_ROOT:-$HOME/tizen-studio}"
# The "platforms" packaging tool lives outside this repository.
platforms_root="${PLATFORMS_ROOT:?Set PLATFORMS_ROOT to a checkout of the platforms packaging tool}"

export PATH="$tizen_root/tools/ide/bin:$tizen_root/tools:$PATH"
export PYTHONPATH="$platforms_root/src:$platforms_root/tools:$platforms_root"

"$platforms_root/.venv/bin/python" -m platforms build \
  --project "$repo_root/samsung/tizen" \
  --platform tizen \
  --json
