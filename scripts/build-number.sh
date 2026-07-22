#!/usr/bin/env bash
#
# File purpose: Allocate a monotonic Mandaza archive build number.
# Primary operation: Select the greatest of the tracked counter plus one,
# project floor, and git commit count.
# I/O: --peek prints the next value; --next persists it to the counter and
# project.yml before XcodeGen regenerates the project.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mode="${1:---peek}"
if [[ "$mode" != "--peek" && "$mode" != "--next" ]]; then
    echo "Usage: scripts/build-number.sh [--peek|--next]" >&2
    exit 2
fi

counter_file="scripts/build-number.txt"
counter="$(tr -d '[:space:]' < "$counter_file")"
configured="$(awk -F: '/CURRENT_PROJECT_VERSION:/ {
    gsub(/[ "]/, "", $2); print $2; exit
}' project.yml)"
git_count="$(git rev-list --count HEAD)"

for candidate in "$counter" "$configured" "$git_count"; do
    [[ "$candidate" =~ ^[0-9]+$ ]] || {
        echo "Invalid build number: $candidate" >&2
        exit 1
    }
done

build="$((counter + 1))"
(( configured > build )) && build="$configured"
(( git_count > build )) && build="$git_count"

if [[ "$mode" == "--next" ]]; then
    printf '%s\n' "$build" > "$counter_file"
    python3 - "$build" <<'PY'
# File Purpose: Update the XcodeGen build number during allocation.
# Primary Functions/Classes: One exact CURRENT_PROJECT_VERSION substitution.
# Inputs and Outputs (I/O): Reads project.yml and writes the allocated number.
from pathlib import Path
import re
import sys

path = Path("project.yml")
text = path.read_text()
updated, count = re.subn(
    r'CURRENT_PROJECT_VERSION:\s*"?[0-9]+"?',
    f'CURRENT_PROJECT_VERSION: "{sys.argv[1]}"',
    text,
    count=1,
)
if count != 1:
    raise SystemExit("CURRENT_PROJECT_VERSION missing or duplicated")
path.write_text(updated)
PY
fi

echo "$build"
