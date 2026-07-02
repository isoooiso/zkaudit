#![no_main]

risc0_zkvm::guest::entry!(main);

#[path = "../suite.rs"]
mod suite;
#[path = "../engine.rs"]
mod engine;
#[path = "../targets/vault_v1.rs"]
mod target;

use engine::{build_journal, run_audit, AuditVault, EngineError};
use risc0_zkvm::guest::env;
use sha2::{Digest, Sha256};
use target::Vault;
use target::VaultError;

impl AuditVault for Vault {
    type Error = VaultError;

    fn v_new(owner: u32) -> Self {
        Vault::new(owner)
    }

    fn v_deposit(&mut self, user: u32, amount: u64) -> Result<(), Self::Error> {
        self.deposit(user, amount)
    }

    fn v_withdraw(&mut self, user: u32, amount: u64) -> Result<(), Self::Error> {
        self.withdraw(user, amount)
    }

    fn v_transfer(&mut self, from: u32, to: u32, amount: u64) -> Result<(), Self::Error> {
        self.transfer(from, to, amount)
    }

    fn v_sweep_fees(&mut self, caller: u32) -> Result<u64, Self::Error> {
        self.sweep_fees(caller)
    }

    fn v_balance_of(&self, user: u32) -> u64 {
        self.balance_of(user)
    }

    fn v_accrued_fees(&self) -> u64 {
        self.accrued_fees()
    }

    fn v_total_assets(&self) -> u64 {
        self.total_assets()
    }
}

fn main() {
    let suite_bytes: Vec<u8> = env::read();
    let contract_hash: [u8; 32] = Sha256::digest(include_bytes!("../targets/vault_v1.rs")).into();

    let journal = match run_audit::<Vault>(&suite_bytes, contract_hash) {
        Ok(j) => j,
        Err(EngineError::Postcard(_)) => build_journal(
            contract_hash,
            Sha256::digest(&suite_bytes).into(),
            0,
            0,
        ),
    };

    env::commit_slice(&journal);
}
