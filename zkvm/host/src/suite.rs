use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct Suite {
    pub tests: Vec<TestCase>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct TestCase {
    pub id: u32,
    pub setup: Vec<Op>,
    pub action: Op,
    pub expect: Expect,
    pub post: Vec<Assertion>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(rename_all = "PascalCase")]
pub enum Op {
    Deposit { user: u32, amount: u64 },
    Withdraw { user: u32, amount: u64 },
    Transfer { from: u32, to: u32, amount: u64 },
    SweepFees { caller: u32 },
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq)]
pub enum Expect {
    Ok,
    ErrAny,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(rename_all = "PascalCase")]
pub enum Assertion {
    BalanceEq { user: u32, expected: u64 },
    FeesEq { expected: u64 },
    Conservation,
}

pub fn decode_journal(journal: &[u8]) -> Option<([u8; 32], [u8; 32], u32, u32)> {
    if journal.len() != 72 {
        return None;
    }
    let mut contract_hash = [0u8; 32];
    let mut suite_commitment = [0u8; 32];
    contract_hash.copy_from_slice(&journal[0..32]);
    suite_commitment.copy_from_slice(&journal[32..64]);
    let n_passed = u32::from_le_bytes(journal[64..68].try_into().ok()?);
    let n_total = u32::from_le_bytes(journal[68..72].try_into().ok()?);
    Some((contract_hash, suite_commitment, n_passed, n_total))
}
