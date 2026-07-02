# zkAudit — ZK-attested smart contract audits on Stellar

**An auditor runs a *private* test suite against a contract off-chain, and posts a succinct proof on Stellar that says "this exact contract passed K of N checks of a committed suite" — without revealing the suite itself.**

The score becomes a public, on-chain attestation. The methodology stays private. Verification is a single pairing-heavy host call on Stellar, not a re-run of the audit.

Built for **Stellar Hacks: Real-World ZK**. ZK is load-bearing: remove it and the whole idea collapses into either "trust the auditor's word" or "publish your entire test suite." See [Why ZK is load-bearing](#why-zk-is-load-bearing).

---

## The problem

Audit results today are PDFs and trust. When an auditor says "this contract is clean," you're trusting their reputation — there's no machine-checkable link between the claim and what was actually tested, and no way to publish a result without also publishing the test suite that produced it. A test suite is the auditor's IP, and publishing it also hands attackers a precise map of what *wasn't* covered.

zkAudit turns an audit result into a cryptographic object:

- The **contract** under audit is bound to the result (by hash).
- The **suite** is bound to the result (by commitment) but never revealed.
- The **score** (`n_passed / n_total`) is proven to be the honest output of running that committed suite against that exact contract.

Anyone can verify the attestation on-chain. Nobody learns the suite.

---

## What it does

```
  auditor (off-chain)                         Stellar (on-chain)
  ┌───────────────────────┐                   ┌────────────────────────┐
  │ private test suite     │                   │ RISC Zero verifier      │
  │        +               │   Groth16 proof   │   (Nethermind router)   │
  │ target contract        │ ────────────────► │        +               │
  │        ↓               │   + public journal│ AttestationRegistry     │
  │ RISC Zero audit engine │                   │   stores {hash, score,  │
  │   → score K/N          │                   │    suite_commitment, …} │
  └───────────────────────┘                   └────────────────────────┘
```

1. The auditor loads a private suite and a target contract into the **audit engine** (a RISC Zero zkVM guest, written in ordinary Rust).
2. The engine runs every test and emits a **public journal**: `contract_hash · suite_commitment · n_passed · n_total`. Everything else — the suite contents, which tests failed — stays inside the proof.
3. A **Groth16 proof** of that execution is generated off-chain.
4. On Stellar, `AttestationRegistry.attest(...)` verifies the proof through Nethermind's RISC Zero router. If the proof is valid, it parses the journal and stores an on-chain **attestation** keyed by `contract_hash`.
5. Anyone calls `get_attestation(contract_hash)` and reads the score, bound to a real execution of a known engine over that exact contract.

---

## Why ZK is load-bearing

The whole product is "a verifiable score without disclosure." That is exactly what a ZK proof buys, and nothing else does:

- **Without ZK, option A — publish the suite.** Now the result is verifiable, but you've leaked the auditor's IP and handed an attacker the exact boundary of what was tested. Non-starter.
- **Without ZK, option B — just post the score.** Now nothing ties the number to reality. The auditor can claim any score. It's back to trust-me.
- **With ZK** — the score is provably the output of running a *committed* suite (`suite_commitment = sha256(suite)`) against a *specific* contract (`contract_hash = sha256(source)`), and the suite is never revealed. The auditor can later prove to a client under NDA exactly which suite that commitment corresponds to, without the chain ever seeing it.

Two negative tests in the demo make the boundary concrete — both **must fail**, and do:

- **Tampered journal.** Flip one byte of the journal (`n_total: 10 → 11`) and call `attest`. The registry hashes the raw journal and hands the digest to the router; the digest no longer matches the proof, so the router **traps** and the whole transaction reverts. You cannot post a score the proof didn't produce.
- **Unregistered engine.** Take a *valid* proof from a different guest (our Phase-1 hello-world) and call `attest`. It's rejected with `EngineNotRegistered` — the proof is real, but it wasn't produced by an audit engine the registry trusts. The score is only meaningful relative to a known engine.

If you deleted the ZK layer, both of these attacks would succeed silently.

---

## Live on Stellar testnet

The public RISC Zero verifier had no testnet deployment, so we deployed the **full Nethermind verifier stack** ourselves and built the registry on top of it. Everything below is live on testnet.

| Contract | ID |
|---|---|
| **AttestationRegistry** (ours) | `CA4KYW64LSPTMCEV4AZVQMEH3WI4IWWO4I7BSZFZ7VGFZAWKH7CI23JE` |
| RISC Zero router (Nethermind) | `CC3K4SGFS3ATCQKDKZNNC3BVDMXC5KXIK7GTZQOMYLIYPVYTVXSWW4N5` |
| Groth16 verifier (Nethermind) | `CBGY7YKUZ4JO6N5KQZ62BAEZJNXSZVMU5ZZK6OGRRPI3EJEC2J7MRAGB` |
| EmergencyStop wrapper | `CB5HP4C7JHEDDQT4EWWUBUILTRB2SFMBW36NOYI7DC3QTDKEWA7HLMMU` |
| Registry admin | `GDKAOBYKNKJDOIHIDWOEW2WUWNDW6IFCOIKTCPW577R4HWBWVJU6OOBU` |

**Registered audit engines** (admin-gated allowlist of `image_id`s):

| Engine | image_id | Demo score |
|---|---|---|
| `audit_v1` (buggy target) | `2b421e8181bdefa2deeecd65802cc4771819332d8e142117427bf69d5235cbc0` | 7 / 10 |
| `audit_v2` (fixed target) | `8bd7b25bdfc8749301140588c11c97df9829bbaa739d227ae08788c00219a951` | 10 / 10 |

**On-chain attestations** (query with `get_attestation`):

| Target | contract_hash (key) | Result |
|---|---|---|
| vault v1 | `1c4426846cccbb0d3823e7bd9feba44f80db11d7f6f9fc23fc7344588a98ee7b` | 7 / 10 |
| vault v2 | `c9442e39c964a1c53df205a9fbce57b351759db139e3ee95b9f73d09a967bd0f` | 10 / 10 |

Both attestations share one `suite_commitment` — `40c583061a7be04d18dffc3fc7c7439408ed7c37969432a19f72a3e9ee820d10` — proving the *same* private suite judged both contracts.

**Key transactions** (stellar.expert / testnet):

- Registry deploy — [`ed469ed6…`](https://stellar.expert/explorer/testnet/tx/ed469ed65062ecee85d24606b7d01e22961799f39951e0ac38cf0822f42c3136)
- Register v1 engine — [`37a76ce6…`](https://stellar.expert/explorer/testnet/tx/37a76ce6f6d11d8e02b52d3099b5ee04fd39bbe50a0ed68182a22e4bae3efb75)
- Register v2 engine — [`1adf28ed…`](https://stellar.expert/explorer/testnet/tx/1adf28edc47c6de7069eddafacced963fec36d668a3d77d934baad35a5ab27ca)
- Attest v1 (7/10) — [`2b87286b…`](https://stellar.expert/explorer/testnet/tx/2b87286bb276b1472a7e04915e0fbae418f74dacbbe3a1e3bbedee010dd04ea3)
- Attest v2 (10/10) — [`570f736e…`](https://stellar.expert/explorer/testnet/tx/570f736ed5f255be7104e69dd52a2b934a4ba8e1f7e5553eaaa984e43c15e518)

---

## The demo: catch bugs, fix them, watch the score move

The target is a minimal token **vault** (`deposit / withdraw / transfer / sweep_fees`). We ship two versions with an identical API. `vault_v1` contains three planted bugs; `vault_v2` fixes them. The **same private 10-test suite** audits both.

Three planted bugs in v1 (each tagged `// BUG(zkaudit-N)` in source):

- **BUG-1 — wrong-variable check.** `withdraw` compares the amount against `total_assets()` instead of the user's own balance → a user can drain funds that aren't theirs. *(caught by T3)*
- **BUG-2 — self-transfer inflation.** `transfer` reads sender and recipient balances into locals and writes both back; when `from == to`, the write-back inflates the balance out of thin air. *(caught by T4)*
- **BUG-3 — missing access control.** `sweep_fees` never checks that the caller is the owner. *(caught by T5)*

Result: **v1 scores 7/10 on-chain. Fix the three bugs → v2 scores 10/10 on-chain.** The score is not self-reported — it's the proven output of the suite, verified by the router before the registry will store it.

---

## Journal format

The public output of every proof is a fixed 72-byte layout — no serde on the proof boundary, so parsing on Soroban is a trivial slice:

```
byte  0..32   contract_hash      sha256 of the target contract source
byte 32..64   suite_commitment   sha256 of the canonical (postcard) suite bytes
byte 64..68   n_passed           u32, little-endian
byte 68..72   n_total            u32, little-endian
```

The guest computes `suite_commitment` over the *exact bytes it received* before decoding them, so the commitment can't drift from what was actually run.

---

## Architecture

```
zkaudit/
├── zkvm/                          # RISC Zero: off-chain proving
│   ├── methods/guest/src/
│   │   ├── engine.rs              # test runner (shared)
│   │   ├── suite.rs               # Suite / TestCase / Op / Expect (serde + postcard)
│   │   ├── targets/vault_v1.rs    # buggy target  (hashed into the journal)
│   │   ├── targets/vault_v2.rs    # fixed target
│   │   └── bin/{audit_v1,audit_v2}.rs   # one guest binary per target
│   └── host/                      # loads suite, proves Groth16, writes proof.txt + journal.hex
├── contracts/attestation-registry/   # Soroban contract (verify via router → store attestation)
├── suites/standard.json           # the 10-test suite (committed, not secret in this PoC — see below)
└── scripts/                       # deploy, verify, demo_e2e
```

Contracts:

- **AttestationRegistry** (`contracts/attestation-registry`) — `attest()` requires auditor auth, checks the `image_id` is an allowlisted engine, hashes the raw journal, calls `RiscZeroVerifierRouterClient::verify(seal, image_id, journal_digest)` (invalid proof traps → tx reverts), then parses the journal and stores an `Attestation{ contract_hash, suite_commitment, n_passed, n_total, image_id, auditor, timestamp, ledger }`. Also `register_engine` (admin-gated), `get_attestation`, `is_engine_registered`.
- **RISC Zero verifier stack** — Nethermind's router / Groth16 verifier / emergency-stop, deployed by us. We call it as a client via the pinned `risc0-interface` crate; we write no cryptography ourselves.

---

## Run it yourself

**Prerequisites:** Rust, Docker (for the Groth16 wrap), `stellar` CLI, and the RISC Zero toolchain (`rzup install` + `rzup install risc0-groth16`). Groth16 proof generation needs an **x86_64 + Docker** host.

```bash
# 1. Dev-mode audit (instant, no proof) — sanity-check scoring
cd zkvm
cargo run -p host --release -- --target v1 --suite ../suites/standard.json --dev
cargo run -p host --release -- --target v2 --suite ../suites/standard.json --dev
#   → v1: 7/10,  v2: 10/10

# 2. Real Groth16 proof (~159s each on our box)
RISC0_DEV_MODE=0 cargo run -p host --release -- --target v1 --suite ../suites/standard.json
RISC0_DEV_MODE=0 cargo run -p host --release -- --target v2 --suite ../suites/standard.json
#   → writes out/proof_{v1,v2}.txt and out/journal_{v1,v2}.hex

# 3. Full on-chain demo (attest both + both negative cases) against live testnet
./scripts/demo_e2e.sh
```

To deploy the whole stack from scratch (verifier + registry + engine registration), see `scripts/checkpoint9_deploy.sh`.

---

## Trust model (read this)

zkAudit is honest about what the proof does and does not guarantee.

**What the proof guarantees.** The stored score is the genuine output of a specific, known audit engine (`image_id`) running over a specific contract (`contract_hash`), and that engine's output cannot be forged or altered — tampering breaks the digest and the router rejects it.

**Why the engine is allowlisted.** In this PoC each target is compiled *into* its own guest binary, so each target produces a distinct `image_id`. The registry therefore keeps an **admin-gated allowlist** of `image_id`s it trusts as "real audit engines." The binding that makes this trustworthy: each guest hashes its own embedded source into the journal (`contract_hash`), and **the guest binaries are reproducible from this public repo** — anyone can rebuild and confirm that a given `image_id` corresponds to this engine over that source. The admin's power is limited to deciding which engines count; it cannot forge a score.

**What you still trust.** (1) The registry admin, to only allowlist honest engines. (2) The Nethermind verifier stack, which is **unaudited** (their own disclaimer) and deployed here for a hackathon. (3) That the auditor's private suite is actually good — ZK proves the suite *ran honestly*, not that the suite is *complete*. `suite_commitment` makes the suite auditable after the fact under NDA, which is the mitigation.

---

## Limitations & production path

This is a proof-of-concept built in a hackathon window. Explicitly:

- **Targets are Rust modules compiled into the guest, not real deployed Wasm.** The engine audits a contract *checked into this repo*, not arbitrary bytecode already on Stellar. This is the biggest gap between PoC and product.
- **Per-target `image_id`** forces the allowlist model above. It works, but it doesn't scale to auditing contracts the engine author has never seen.
- **The suite in `suites/standard.json` is in the repo** for reproducibility of the *demo*. In real use the suite stays private on the auditor's machine; only its commitment is ever public. Nothing in the protocol requires the suite to be published — the demo publishes it so judges can verify the scores.

**The production path closes all three at once:** replace the per-target guests with **one** guest that is a **Wasm interpreter**. The target contract's Wasm becomes an *input* rather than compile-time source. That yields a single stable `image_id` (no per-target allowlist), and — since Soroban contracts *are* Wasm — it lets you audit real, already-deployed Stellar contracts by hash. The journal format, the registry, and the verification path all stay exactly as they are here.

---

## Development notes

A few environment findings from building this on WSL2 + Docker Desktop, kept here because they cost real time and might save someone else's:

- **Groth16 proving needs x86_64 + Docker.** The base RISC Zero toolchain (~500 MB) and the separate `risc0-groth16` proving material (~2.18 GB) are large; on a throttled link, generate proofs on an x86_64 Linux box and run the (lightweight) Stellar verification steps from anywhere — exactly the split Nethermind's docs recommend.
- **Docker-from-WSL path translation.** The Groth16 STARK→SNARK wrap shells out to `docker.exe`, which needs Windows-style volume paths. `wslpath -w` can translate DrvFS paths (`/mnt/c/...`) but **not** native WSL paths (`/home/...`), so `RISC0_WORK_DIR` must live under `/mnt/c/...`. A small wrapper (`scripts/docker_wsl_wrapper.sh`) converts volume args via `wslpath`.
- **RISC Zero guest `no_std` collections.** `BTreeMap` misbehaved under the guest toolchain; the vault's balance store uses `Vec<(u32, u64)>` instead. Fine at this scale.
- **Guest binaries share code via `#[path]`**, since risc0 builds the bins without linking a lib crate.
- **Version pinning is not optional.** The proof's RISC Zero version must match the deployed verifier's Groth16 parameters (3.0.x line here), or on-chain verification fails. `risc0-interface` is pinned to the exact git rev we deployed from.

---

## Tech stack

- **RISC Zero zkVM** (Rust guest, Groth16 receipts) — off-chain proving. *[risczero.com](https://www.risczero.com/)*
- **Nethermind Stellar RISC Zero verifier** — on-chain Groth16 verification (BN254 host functions, Protocol 25/26). *[github.com/NethermindEth/stellar-risc0-verifier](https://github.com/NethermindEth/stellar-risc0-verifier)*
- **Soroban** (`soroban-sdk`) — the AttestationRegistry contract.
- **postcard** — canonical suite serialization; **sha256** for both commitments.

## Author

Built by [@`<your-github-username>`](https://github.com/<your-github-username>) for Stellar Hacks: Real-World ZK.

## License

Apache-2.0. The vendored Nethermind verifier retains its own Apache-2.0 license.

> **Note:** This project has **not been audited** and is a hackathon proof-of-concept. The vendored RISC Zero verifier is likewise unaudited. Do not use with real assets.
