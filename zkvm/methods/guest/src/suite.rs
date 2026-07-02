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
