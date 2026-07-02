#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/bin"
ln -sf /mnt/c/Users/petre/Desktop/zkaudit/scripts/docker_wsl_wrapper.sh "$HOME/bin/docker"
chmod +x "$HOME/bin/docker"
export PATH="$HOME/bin:$HOME/.cargo/bin:/usr/bin:/bin"
export RISC0_DEV_MODE=0
# Groth16 docker.exe mounts require a DrvFS path wslpath can translate.
ROOT=/mnt/c/Users/petre/Desktop/zkaudit/zkvm
rsync -a "$HOME/zkaudit/zkvm/host/" "$ROOT/host/" 2>/dev/null || true
rsync -a "$HOME/zkaudit/zkvm/methods/" "$ROOT/methods/" 2>/dev/null || true
rsync -a "$HOME/zkaudit/zkvm/suites/" "$ROOT/suites/" 2>/dev/null || true
cd "$ROOT"
mkdir -p out logs

for target in v1 v2; do
  echo "=== Groth16 $target ==="
  WORK="$ROOT/groth-work-${target}"
  rm -rf "$WORK"
  mkdir -p "$WORK"
  export RISC0_WORK_DIR="$WORK"
  start=$(date +%s)
  cargo run -p host --release -- --target "$target" --suite suites/standard.json 2>&1 | tee "logs/groth16_${target}.log"
  end=$(date +%s)
  echo "proving_seconds_${target}=$((end - start))"
  seal_prefix=$(sed -n '1p' "out/proof_${target}.txt" | cut -c1-32)
  echo "seal_prefix_${target}=${seal_prefix}"
done

cp logs/groth16_*.log /mnt/c/Users/petre/Desktop/zkaudit/logs/ 2>/dev/null || true
