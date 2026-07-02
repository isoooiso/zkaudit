# zkAudit

ZK-attested smart contract audits — Phase 1 proving and verification skeleton.

## Cloud proving workflow

Local WSL downloads of `rzup` / `risc0-groth16` are often slow and unstable. Use a temporary **Ubuntu 24.04 x86_64** VPS instead:

1. Push this repo to GitHub.
2. Bootstrap and prove on the server using the scripts in [`scripts/cloud_proving/`](scripts/cloud_proving/README.md).
3. Download artifacts back to Windows with `scripts/cloud_proving/fetch_outputs.ps1`.

Full step-by-step instructions: **[scripts/cloud_proving/README.md](scripts/cloud_proving/README.md)**
