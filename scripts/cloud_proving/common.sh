#!/usr/bin/env bash
# Shared helpers for cloud proving scripts.
# shellcheck disable=SC2034

# Repository root (zkaudit/), two levels up from scripts/cloud_proving/
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

setup_proving_env() {
  export PATH="${HOME}/.risc0/bin:${HOME}/.cargo/bin:${PATH}"
  # shellcheck source=/dev/null
  if [[ -f "${HOME}/.cargo/env" ]]; then
    source "${HOME}/.cargo/env"
  fi
  # shellcheck source=/dev/null
  if [[ -f "${HOME}/.bashrc" ]]; then
    source "${HOME}/.bashrc" 2>/dev/null || true
  fi
}

ensure_output_dirs() {
  mkdir -p "${REPO_ROOT}/logs" "${REPO_ROOT}/artifacts"
}

print_tool_versions() {
  echo "=== Tool versions ==="
  uname -a
  rustc --version
  cargo --version
  if command -v rzup >/dev/null 2>&1; then
    rzup --version
    rzup show
  else
    echo "WARNING: rzup not found on PATH. Run bootstrap_ubuntu.sh first."
  fi
  if cargo risczero --version 2>/dev/null; then
    :
  else
    echo "WARNING: cargo risczero not available."
  fi
  echo "=== Repository root: ${REPO_ROOT} ==="
}

# Detect the host/prover cargo package name.
# Prefers a workspace member directory named "host", then any member that
# looks like a RISC Zero host (depends on risc0-ethereum-contracts or methods).
detect_host_package() {
  local root="${1:-${REPO_ROOT}}"
  local cargo_toml="${root}/Cargo.toml"

  if [[ ! -f "${cargo_toml}" ]]; then
    cat >&2 <<'EOF'
ERROR: No Cargo.toml at repository root.

Proving requires a RISC Zero workspace with a host/prover package. Expected
after Checkpoint 2, for example:

  cargo risczero new zkvm --guest-name audit_engine

That scaffolds a workspace with a "host" package. Commit and push the
workspace, then re-run this script on the cloud server.
EOF
    return 1
  fi

  # 1) Canonical name from RISC Zero template
  if [[ -f "${root}/host/Cargo.toml" ]]; then
    if grep -Eq 'risc0-zkvm|risc0-ethereum-contracts|methods' "${root}/host/Cargo.toml" 2>/dev/null; then
      echo "host"
      return 0
    fi
    # host/ exists even if deps not wired yet
    echo "host"
    return 0
  fi

  # 2) Other common host directory names
  local candidate
  for candidate in prover cli runner; do
    if [[ -f "${root}/${candidate}/Cargo.toml" ]] \
      && grep -Eq 'risc0-ethereum-contracts|methods|risc0-zkvm' "${root}/${candidate}/Cargo.toml" 2>/dev/null; then
      echo "${candidate}"
      return 0
    fi
  done

  # 3) Scan top-level packages for host-like dependencies (exclude guest crates)
  local dir pkg_name
  for dir in "${root}"/*/; do
    [[ -f "${dir}Cargo.toml" ]] || continue
    pkg_name="$(basename "${dir}")"
    [[ "${pkg_name}" == "target" || "${pkg_name}" == "scripts" || "${pkg_name}" == "vendor" ]] && continue

    if grep -q 'risc0-zkvm' "${dir}Cargo.toml" 2>/dev/null \
      && grep -Eq 'risc0-ethereum-contracts|methods' "${dir}Cargo.toml" 2>/dev/null; then
      echo "${pkg_name}"
      return 0
    fi
  done

  # 4) Single-package repo at root with host deps
  if grep -Eq 'risc0-ethereum-contracts|methods' "${cargo_toml}" 2>/dev/null; then
    local name
    name="$(grep -E '^name\s*=' "${cargo_toml}" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
    if [[ -n "${name}" ]]; then
      echo "${name}"
      return 0
    fi
  fi

  cat >&2 <<EOF
ERROR: Could not detect a host/prover package in ${root}.

Looked for:
  - host/Cargo.toml (RISC Zero default)
  - packages with risc0-ethereum-contracts or methods dependencies

Workspace members (if any):
$(grep -E 'members|"' "${cargo_toml}" 2>/dev/null | head -20 || echo "  (could not parse)")

Fix: add a host package or rename your prover crate to "host", then re-run.
EOF
  return 1
}

list_generated_outputs() {
  local root="${1:-${REPO_ROOT}}"
  echo ""
  echo "=== Generated outputs (repo root, artifacts/, and common names) ==="

  local pattern path
  for pattern in \
    "proof.txt" \
    "journal.hex" \
    "seal.hex" \
    "receipt.json" \
    "receipt.bin" \
    "artifacts/proof.txt" \
    "artifacts/journal.hex" \
    "artifacts/seal.hex" \
    "artifacts/receipt.json" \
    "artifacts/receipt.bin" \
    "logs/rzup-show.txt"
  do
    path="${root}/${pattern}"
    if [[ -e "${path}" ]]; then
      echo "  FOUND: ${pattern} ($(wc -c < "${path}" | tr -d ' ') bytes)"
    fi
  done

  shopt -s nullglob
  local f
  for f in "${root}"/*.proof "${root}"/*.receipt "${root}/artifacts"/*; do
    [[ -e "${f}" ]] || continue
    echo "  FOUND: ${f#${root}/} ($(wc -c < "${f}" | tr -d ' ') bytes)"
  done
  shopt -u nullglob

  if [[ -d "${root}/artifacts" ]] && [[ -z "$(ls -A "${root}/artifacts" 2>/dev/null)" ]]; then
    echo "  (artifacts/ exists but is empty)"
  fi

  local missing=0
  for pattern in "artifacts/proof.txt" "artifacts/journal.hex"; do
    if [[ ! -f "${root}/${pattern}" ]]; then
      echo "  MISSING (expected after real Groth16): ${pattern}"
      missing=1
    fi
  done
  if [[ "${missing}" -eq 1 ]]; then
    echo ""
    echo "NOTE: If the host writes proof.txt / journal.hex only to stdout or repo root,"
    echo "update host/src/main.rs to also write:"
    echo "  artifacts/proof.txt   (seal, image_id, journal_digest hex lines)"
    echo "  artifacts/journal.hex (raw journal bytes)"
  fi
}
