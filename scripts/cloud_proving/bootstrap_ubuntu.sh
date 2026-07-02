#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

mkdir -p logs
LOG_FILE="${REPO_ROOT}/logs/cloud-bootstrap.log"

log() {
  echo "$@"
}

run_bootstrap() {
  log "=== zkaudit cloud bootstrap ==="
  log "Started: $(date -Is)"
  log "Repo root: ${REPO_ROOT}"
  uname -a

  log ""
  log "=== apt packages ==="
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -qq
  sudo apt-get install -y \
    build-essential \
    curl \
    git \
    pkg-config \
    libssl-dev \
    ca-certificates \
    unzip \
    htop \
    tmux

  log ""
  log "=== Rust (rustup) ==="
  if ! command -v rustc >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  else
    log "rustc already installed: $(rustc --version)"
  fi

  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
  export PATH="${HOME}/.cargo/bin:${PATH}"

  log ""
  log "=== RISC Zero (rzup) ==="
  if ! command -v rzup >/dev/null 2>&1; then
    curl -L https://risczero.com/install | bash
  else
    log "rzup already installed: $(rzup --version)"
  fi

  export PATH="${HOME}/.risc0/bin:${HOME}/.cargo/bin:${PATH}"

  # Persist PATH in ~/.bashrc (idempotent)
  for line in \
    'export PATH="$HOME/.risc0/bin:$HOME/.cargo/bin:$PATH"' \
    '[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"'
  do
    if ! grep -Fq "${line}" "${HOME}/.bashrc" 2>/dev/null; then
      echo "${line}" >> "${HOME}/.bashrc"
    fi
  done

  log ""
  log "=== rzup install (toolchain + groth16) ==="
  rzup install
  rzup install risc0-groth16

  log ""
  log "=== Version summary ==="
  rustc --version
  cargo --version
  rzup --version
  rzup show | tee "${REPO_ROOT}/logs/rzup-show.txt"
  cp "${REPO_ROOT}/logs/rzup-show.txt" "${REPO_ROOT}/rzup-show.txt" 2>/dev/null || true
  cargo risczero --version

  log ""
  log "Finished: $(date -Is)"
  log "Log saved to: ${LOG_FILE}"
}

{
  run_bootstrap
} 2>&1 | tee "${LOG_FILE}"
