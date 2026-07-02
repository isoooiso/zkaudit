mod suite;

use methods::{AUDIT_V1_ELF, AUDIT_V1_ID, AUDIT_V2_ELF, AUDIT_V2_ID};
use risc0_ethereum_contracts::encode_seal;
use risc0_zkvm::{default_executor, default_prover, sha::Digest, ExecutorEnv, ProverOpts};
use sha2::{Digest as Sha256Digest, Sha256};
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process;
use std::time::Instant;

#[derive(Clone, Copy)]
enum Target {
    V1,
    V2,
}

struct Args {
    target: Target,
    suite_path: PathBuf,
    dev: bool,
}

fn main() {
    let args = parse_args();

    let suite_json = fs::read_to_string(&args.suite_path).unwrap_or_else(|e| {
        eprintln!("failed to read suite {}: {e}", args.suite_path.display());
        process::exit(1);
    });
    let suite: suite::Suite = serde_json::from_str(&suite_json).unwrap_or_else(|e| {
        eprintln!("invalid suite JSON: {e}");
        process::exit(1);
    });
    let suite_bytes = postcard::to_allocvec(&suite).unwrap_or_else(|e| {
        eprintln!("failed to serialize suite with postcard: {e}");
        process::exit(1);
    });

    let (elf, image_id, target_name) = match args.target {
        Target::V1 => (AUDIT_V1_ELF, AUDIT_V1_ID, "v1"),
        Target::V2 => (AUDIT_V2_ELF, AUDIT_V2_ID, "v2"),
    };

    let env = ExecutorEnv::builder()
        .write(&suite_bytes)
        .unwrap_or_else(|e| {
            eprintln!("failed to write suite into executor env: {e}");
            process::exit(1);
        })
        .build()
        .unwrap_or_else(|e| {
            eprintln!("failed to build executor env: {e}");
            process::exit(1);
        });

    if args.dev {
        let session = default_executor().execute(env, elf).unwrap_or_else(|e| {
            eprintln!("execution failed: {e}");
            process::exit(1);
        });
        let journal = session.journal.bytes.as_slice();
        print_decoded_journal(target_name, image_id, journal);
        return;
    }

    let prover = default_prover();
    let opts = ProverOpts::groth16();
    let start = Instant::now();
    let prove_info = prover
        .prove_with_opts(env, elf, &opts)
        .unwrap_or_else(|e| {
            eprintln!("Groth16 proving failed: {e}");
            process::exit(1);
        });
    let elapsed = start.elapsed();

    let receipt = prove_info.receipt;
    let seal = encode_seal(&receipt).unwrap_or_else(|e| {
        eprintln!("encode_seal failed: {e}");
        process::exit(1);
    });
    let journal_digest: [u8; 32] = Sha256::digest(receipt.journal.bytes.as_slice()).into();
    let image_digest: Digest = image_id.into();

    fs::create_dir_all("out").unwrap_or_else(|e| {
        eprintln!("failed to create out/: {e}");
        process::exit(1);
    });

    let proof_path = format!("out/proof_{target_name}.txt");
    let journal_path = format!("out/journal_{target_name}.hex");
    let proof_out = format!(
        "{}\n{}\n{}\n",
        hex::encode(&seal),
        hex::encode(image_digest.as_bytes()),
        hex::encode(journal_digest)
    );
    fs::write(&proof_path, proof_out).unwrap_or_else(|e| {
        eprintln!("write {proof_path}: {e}");
        process::exit(1);
    });
    fs::write(&journal_path, hex::encode(receipt.journal.bytes.as_slice())).unwrap_or_else(|e| {
        eprintln!("write {journal_path}: {e}");
        process::exit(1);
    });

    println!("proving_seconds={:.2}", elapsed.as_secs_f64());
    println!("seal_prefix={}", &hex::encode(&seal)[..32]);
    print_decoded_journal(target_name, image_id, receipt.journal.bytes.as_slice());
    println!("wrote {proof_path} and {journal_path}");
}

fn print_decoded_journal(target_name: &str, image_id: [u32; 8], journal: &[u8]) {
    let image_digest: Digest = image_id.into();
    if let Some((contract_hash, suite_commitment, n_passed, n_total)) =
        suite::decode_journal(journal)
    {
        println!("target={target_name}");
        println!("image_id={}", hex::encode(image_digest.as_bytes()));
        println!("contract_hash={}", hex::encode(contract_hash));
        println!("suite_commitment={}", hex::encode(suite_commitment));
        println!("n_passed={n_passed}");
        println!("n_total={n_total}");
        println!("score={n_passed}/{n_total}");
    } else {
        eprintln!("unexpected journal length {}", journal.len());
        process::exit(1);
    }
}

fn parse_args() -> Args {
    let mut target: Option<Target> = None;
    let mut suite_path: Option<PathBuf> = None;
    let mut dev = false;

    let mut iter = env::args().skip(1);
    while let Some(arg) = iter.next() {
        match arg.as_str() {
            "--target" => {
                let value = iter.next().unwrap_or_else(|| usage("missing --target value"));
                target = Some(match value.as_str() {
                    "v1" => Target::V1,
                    "v2" => Target::V2,
                    other => {
                        eprintln!("unknown target {other}");
                        usage("expected v1 or v2");
                    }
                });
            }
            "--suite" => {
                suite_path = Some(PathBuf::from(
                    iter.next().unwrap_or_else(|| usage("missing --suite path")),
                ));
            }
            "--dev" => dev = true,
            other => {
                eprintln!("unknown argument {other}");
                usage("unrecognized argument");
            }
        }
    }

    let target = target.unwrap_or_else(|| usage("missing --target"));
    let suite_path = suite_path.unwrap_or_else(|| usage("missing --suite"));

    Args {
        target,
        suite_path,
        dev,
    }
}

fn usage(reason: &str) -> ! {
    eprintln!("error: {reason}");
    eprintln!(
        "usage: cargo run -p host --release -- --target v1|v2 --suite suites/standard.json [--dev]"
    );
    process::exit(1);
}
