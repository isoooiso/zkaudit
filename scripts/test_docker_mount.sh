#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/bin:/usr/bin:/bin"
DIR=/mnt/c/Users/petre/Desktop/zkaudit/zkvm/groth-work
WINPATH=$(wslpath -w "$DIR" | tr '\\' '/')
echo "Windows path: $WINPATH"
docker run --rm -v "${WINPATH}:/mnt" alpine wc -c /mnt/input.json
