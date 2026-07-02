#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

cd "${REPO_ROOT}"
ensure_output_dirs
LOG_FILE="${REPO_ROOT}/logs/cp3-real-groth16.log"

run_real_groth16() {
  setup_proving_env
  print_tool_versions

  if ! command -v docker >/dev/null 2>&1; then
    echo "WARNING: docker not found. Groth16 wrapping usually requires Docker."
    echo "Install Docker on the server or ensure risc0-groth16 local prover is configured."
  elif docker ps >/dev/null 2>&1; then
    echo "Docker: OK ($(docker --version 2>/dev/null || echo unknown))"
  else
    echo "WARNING: docker installed but daemon not reachable (docker ps failed)."
  fi

  echo ""
  echo "=== Detecting host/prover package ==="
  local pkg
  if ! pkg="$(detect_host_package)"; then
    exit 1
  fi
  echo "Using cargo package: ${pkg}"

  echo ""
  echo "=== RISC0_DEV_MODE=0 cargo run -p ${pkg} --release ==="
  echo "Started: $(date -Is)"
  echo "(Groth16 wrap may take several minutes on first run while Docker images pull.)"

  local start_ts end_ts elapsed
  start_ts=$(date +%s)

  RISC0_DEV_MODE=0 cargo run -p "${pkg}" --release

  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  echo ""
  echo "Proving elapsed: ${elapsed}s"

  # Copy root-level outputs into artifacts/ if host wrote them there
  for name in proof.txt journal.hex seal.hex receipt.json receipt.bin; do
    if [[ -f "${REPO_ROOT}/${name}" && ! -f "${REPO_ROOT}/artifacts/${name}" ]]; then
      cp "${REPO_ROOT}/${name}" "${REPO_ROOT}/artifacts/${name}"
      echo "Copied ${name} -> artifacts/${name}"
    fi
  done

  echo ""
  echo "Finished: $(date -Is)"
  list_generated_outputs
}

{
  run_real_groth16
} 2>&1 | tee "${LOG_FILE}"

echo ""
echo "Log saved to: ${LOG_FILE}"
