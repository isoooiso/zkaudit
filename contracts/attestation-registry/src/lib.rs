#![no_std]

use risc0_interface::RiscZeroVerifierRouterClient;
use soroban_sdk::{
    contract, contracterror, contractimpl, contracttype, symbol_short, Address, Bytes, BytesN,
    Env,
};

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Attestation {
    pub contract_hash: BytesN<32>,
    pub suite_commitment: BytesN<32>,
    pub n_passed: u32,
    pub n_total: u32,
    pub image_id: BytesN<32>,
    pub auditor: Address,
    pub timestamp: u64,
    pub ledger: u32,
}

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq)]
#[repr(u32)]
pub enum Error {
    EngineNotRegistered = 1,
    BadJournalLen = 2,
    NotAdmin = 3,
}

#[contracttype]
#[derive(Clone)]
enum DataKey {
    Admin,
    Router,
    Engine(BytesN<32>),
    Att(BytesN<32>),
}

const JOURNAL_LEN: u32 = 72;

#[contract]
pub struct AttestationRegistry;

#[contractimpl]
impl AttestationRegistry {
    pub fn __constructor(env: Env, admin: Address, router: Address) {
        env.storage().instance().set(&DataKey::Admin, &admin);
        env.storage().instance().set(&DataKey::Router, &router);
    }

    pub fn register_engine(env: Env, image_id: BytesN<32>) {
        let admin: Address = env
            .storage()
            .instance()
            .get(&DataKey::Admin)
            .expect("admin not set");
        admin.require_auth();
        env.storage()
            .persistent()
            .set(&DataKey::Engine(image_id), &true);
    }

    pub fn attest(
        env: Env,
        auditor: Address,
        seal: Bytes,
        image_id: BytesN<32>,
        journal: Bytes,
    ) -> Result<(), Error> {
        auditor.require_auth();

        if !Self::is_engine_registered(env.clone(), image_id.clone()) {
            return Err(Error::EngineNotRegistered);
        }

        if journal.len() != JOURNAL_LEN {
            return Err(Error::BadJournalLen);
        }

        let journal_digest = env.crypto().sha256(&journal).to_bytes();
        let router: Address = env
            .storage()
            .instance()
            .get(&DataKey::Router)
            .expect("router not set");
        RiscZeroVerifierRouterClient::new(&env, &router).verify(
            &seal,
            &image_id,
            &journal_digest,
        );

        let mut raw = [0u8; 72];
        journal.copy_into_slice(&mut raw);

        let mut contract_hash = [0u8; 32];
        contract_hash.copy_from_slice(&raw[0..32]);
        let contract_hash = BytesN::from_array(&env, &contract_hash);

        let mut suite_commitment = [0u8; 32];
        suite_commitment.copy_from_slice(&raw[32..64]);
        let suite_commitment = BytesN::from_array(&env, &suite_commitment);

        let n_passed = u32::from_le_bytes(raw[64..68].try_into().expect("n_passed"));
        let n_total = u32::from_le_bytes(raw[68..72].try_into().expect("n_total"));

        let attestation = Attestation {
            contract_hash: contract_hash.clone(),
            suite_commitment,
            n_passed,
            n_total,
            image_id: image_id.clone(),
            auditor: auditor.clone(),
            timestamp: env.ledger().timestamp(),
            ledger: env.ledger().sequence(),
        };

        env.storage()
            .persistent()
            .set(&DataKey::Att(contract_hash.clone()), &attestation);

        env.events().publish(
            (symbol_short!("attest"), contract_hash),
            (n_passed, n_total, image_id, auditor),
        );

        Ok(())
    }

    pub fn get_attestation(env: Env, contract_hash: BytesN<32>) -> Option<Attestation> {
        env.storage()
            .persistent()
            .get(&DataKey::Att(contract_hash))
    }

    pub fn is_engine_registered(env: Env, image_id: BytesN<32>) -> bool {
        env.storage()
            .persistent()
            .get(&DataKey::Engine(image_id))
            .unwrap_or(false)
    }
}

#[cfg(test)]
mod test;
