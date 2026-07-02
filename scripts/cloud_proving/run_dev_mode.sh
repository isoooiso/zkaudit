#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

cd "${REPO_ROOT}"
ensure_output_dirs
LOG_FILE="${REPO_ROOT}/logs/cp2-dev-mode.log"

run_dev_mode() {
  setup_proving_env
  print_tool_versions

  echo ""
  echo "=== Detecting host/prover package ==="
  local pkg
  if ! pkg="$(detect_host_package)"; then
    exit 1
  fi
  echo "Using cargo package: ${pkg}"

  echo ""
  echo "=== RISC0_DEV_MODE=1 cargo run -p ${pkg} ==="
  echo "Started: $(date -Is)"

  RISC0_DEV_MODE=1 cargo run -p "${pkg}"

  echo ""
  echo "Finished: $(date -Is)"
  list_generated_outputs
}

{
  run_dev_mode
} 2>&1 | tee "${LOG_FILE}"

echo ""
echo "Log saved to: ${LOG_FILE}"
