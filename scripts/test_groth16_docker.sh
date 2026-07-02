#!/usr/bin/env bash
set -x
export PATH="$HOME/bin:/usr/bin:/bin"
WORK=/tmp/groth16-test
mkdir -p "$WORK"
echo '{}' > "$WORK/input.json"
docker pull risczero/risc0-groth16-prover:v2025-04-03.1
docker run --rm -v "$WORK:/mnt" risczero/risc0-groth16-prover:v2025-04-03.1 2>&1
