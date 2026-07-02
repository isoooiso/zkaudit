use crate::suite::{Assertion, Expect, Op, Suite, TestCase};
use postcard::{from_bytes, Error as PostcardError};
use sha2::{Digest, Sha256};

pub const OWNER: u32 = 0;

pub trait AuditVault {
    type Error;
    fn v_new(owner: u32) -> Self;
    fn v_deposit(&mut self, user: u32, amount: u64) -> Result<(), Self::Error>;
    fn v_withdraw(&mut self, user: u32, amount: u64) -> Result<(), Self::Error>;
    fn v_transfer(&mut self, from: u32, to: u32, amount: u64) -> Result<(), Self::Error>;
    fn v_sweep_fees(&mut self, caller: u32) -> Result<u64, Self::Error>;
    fn v_balance_of(&self, user: u32) -> u64;
    fn v_accrued_fees(&self) -> u64;
    fn v_total_assets(&self) -> u64;
}

#[derive(Debug)]
pub enum EngineError {
    Postcard(PostcardError),
}

pub fn run_audit<V: AuditVault>(
    suite_bytes: &[u8],
    contract_hash: [u8; 32],
) -> Result<[u8; 72], EngineError> {
    let suite_commitment: [u8; 32] = Sha256::digest(suite_bytes).into();
    let suite: Suite = from_bytes(suite_bytes).map_err(EngineError::Postcard)?;

    let mut passed: u32 = 0;
    let total: u32 = suite.tests.len() as u32;

    for test in &suite.tests {
        if run_test_case::<V>(test) {
            passed = passed.saturating_add(1);
        }
    }

    Ok(build_journal(
        contract_hash,
        suite_commitment,
        passed,
        total,
    ))
}

fn run_test_case<V: AuditVault>(test: &TestCase) -> bool {
    let mut vault = V::v_new(OWNER);
    let mut users: Vec<u32> = Vec::new();

    for op in &test.setup {
        track_op_users(op, &mut users);
        if exec_op(&mut vault, op).is_err() {
            return false;
        }
    }

    track_op_users(&test.action, &mut users);
    let action_ok = exec_op(&mut vault, &test.action).is_ok();
    let expect_ok = match test.expect {
        Expect::Ok => action_ok,
        Expect::ErrAny => !action_ok,
    };
    if !expect_ok {
        return false;
    }

    for assertion in &test.post {
        if !check_assertion(&vault, assertion, &users) {
            return false;
        }
    }

    true
}

fn track_user(users: &mut Vec<u32>, user: u32) {
    if !users.iter().any(|u| *u == user) {
        users.push(user);
    }
}

fn track_op_users(op: &Op, users: &mut Vec<u32>) {
    match op {
        Op::Deposit { user, .. } => track_user(users, *user),
        Op::Withdraw { user, .. } => track_user(users, *user),
        Op::Transfer { from, to, .. } => {
            track_user(users, *from);
            track_user(users, *to);
        }
        Op::SweepFees { caller } => track_user(users, *caller),
    }
}

fn exec_op<V: AuditVault>(vault: &mut V, op: &Op) -> Result<(), V::Error> {
    match op {
        Op::Deposit { user, amount } => vault.v_deposit(*user, *amount),
        Op::Withdraw { user, amount } => vault.v_withdraw(*user, *amount),
        Op::Transfer { from, to, amount } => vault.v_transfer(*from, *to, *amount),
        Op::SweepFees { caller } => vault.v_sweep_fees(*caller).map(|_| ()),
    }
}

fn check_assertion<V: AuditVault>(
    vault: &V,
    assertion: &Assertion,
    users: &[u32],
) -> bool {
    match assertion {
        Assertion::BalanceEq { user, expected } => vault.v_balance_of(*user) == *expected,
        Assertion::FeesEq { expected } => vault.v_accrued_fees() == *expected,
        Assertion::Conservation => conservation_holds(vault, users),
    }
}

fn conservation_holds<V: AuditVault>(vault: &V, users: &[u32]) -> bool {
    let mut sum = 0u64;
    for user in users {
        sum = match sum.checked_add(vault.v_balance_of(*user)) {
            Some(v) => v,
            None => return false,
        };
    }
    match sum.checked_add(vault.v_accrued_fees()) {
        Some(left) => left == vault.v_total_assets(),
        None => false,
    }
}

pub fn build_journal(
    contract_hash: [u8; 32],
    suite_commitment: [u8; 32],
    n_passed: u32,
    n_total: u32,
) -> [u8; 72] {
    let mut journal = [0u8; 72];
    journal[0..32].copy_from_slice(&contract_hash);
    journal[32..64].copy_from_slice(&suite_commitment);
    journal[64..68].copy_from_slice(&n_passed.to_le_bytes());
    journal[68..72].copy_from_slice(&n_total.to_le_bytes());
    journal
}

pub fn decode_journal(journal: &[u8; 72]) -> ([u8; 32], [u8; 32], u32, u32) {
    let mut contract_hash = [0u8; 32];
    let mut suite_commitment = [0u8; 32];
    contract_hash.copy_from_slice(&journal[0..32]);
    suite_commitment.copy_from_slice(&journal[32..64]);
    let n_passed = u32::from_le_bytes(journal[64..68].try_into().unwrap());
    let n_total = u32::from_le_bytes(journal[68..72].try_into().unwrap());
    (contract_hash, suite_commitment, n_passed, n_total)
}
