#!/bin/bash
# Deploy Claude assets (commands, skills, agents) from this repo into ~/.claude/.
# The repo is the source of truth; ~/.claude/ is the live install.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/../claude" && pwd)"
DEST="$HOME/.claude"

echo "Deploying $SRC -> $DEST"
for sub in commands skills agents; do
    if [ -d "$SRC/$sub" ]; then
        mkdir -p "$DEST/$sub"
        cp -v "$SRC/$sub/"*.md "$DEST/$sub/" 2>/dev/null || true
    fi
done
echo "Done."
