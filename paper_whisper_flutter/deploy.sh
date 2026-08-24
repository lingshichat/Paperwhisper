#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "This compatibility entry now delegates to the full dual-platform release workflow."
exec pwsh -NoProfile -File "$REPOSITORY_ROOT/scripts/release.ps1" "$@"
