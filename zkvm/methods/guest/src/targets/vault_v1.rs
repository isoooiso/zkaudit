#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VaultError {
    InsufficientBalance,
    NotOwner,
    ZeroAmount,
    Overflow,
}

struct Balances {
    entries: Vec<(u32, u64)>,
}

impl Balances {
    fn new() -> Self {
        Self {
            entries: Vec::new(),
        }
    }

    fn get(&self, user: u32) -> u64 {
        for (u, bal) in &self.entries {
            if *u == user {
                return *bal;
            }
        }
        0
    }

    fn set(&mut self, user: u32, amount: u64) -> Result<(), VaultError> {
        if amount == 0 {
            if let Some(idx) = self.entries.iter().position(|(u, _)| *u == user) {
                self.entries.swap_remove(idx);
            }
            return Ok(());
        }
        for (u, bal) in &mut self.entries {
            if *u == user {
                *bal = amount;
                return Ok(());
            }
        }
        self.entries.push((user, amount));
        Ok(())
    }

    fn sum(&self) -> u64 {
        let mut sum = 0u64;
        for (_, bal) in &self.entries {
            sum = sum.saturating_add(*bal);
        }
        sum
    }
}

pub struct Vault {
    owner: u32,
    balances: Balances,
    accrued_fees: u64,
}

impl Vault {
    pub fn new(owner: u32) -> Self {
        Self {
            owner,
            balances: Balances::new(),
            accrued_fees: 0,
        }
    }

    fn get_balance(&self, user: u32) -> u64 {
        self.balances.get(user)
    }

    fn set_balance(&mut self, user: u32, amount: u64) -> Result<(), VaultError> {
        self.balances.set(user, amount)
    }

    pub fn deposit(&mut self, user: u32, amount: u64) -> Result<(), VaultError> {
        if amount == 0 {
            return Err(VaultError::ZeroAmount);
        }
        let new_bal = self
            .get_balance(user)
            .checked_add(amount)
            .ok_or(VaultError::Overflow)?;
        self.set_balance(user, new_bal)
    }

    pub fn withdraw(&mut self, user: u32, amount: u64) -> Result<(), VaultError> {
        if amount == 0 {
            return Err(VaultError::ZeroAmount);
        }
        // BUG(zkaudit-1): checks pool total instead of user balance; allows overdraw via saturating_sub
        if amount > self.total_assets() {
            return Err(VaultError::InsufficientBalance);
        }
        let bal = self.get_balance(user);
        let new_bal = bal.saturating_sub(amount);
        self.set_balance(user, new_bal)
    }

    pub fn transfer(&mut self, from: u32, to: u32, amount: u64) -> Result<(), VaultError> {
        if amount == 0 {
            return Err(VaultError::ZeroAmount);
        }
        let from_bal = self.get_balance(from);
        if amount > from_bal {
            return Err(VaultError::InsufficientBalance);
        }
        let fee = amount / 100;
        let to_amount = amount.checked_sub(fee).ok_or(VaultError::Overflow)?;

        // BUG(zkaudit-2): locals + write-back inflates balance on self-transfer
        let new_from = from_bal.checked_sub(amount).ok_or(VaultError::Overflow)?;
        let new_to = self
            .get_balance(to)
            .checked_add(to_amount)
            .ok_or(VaultError::Overflow)?;
        self.set_balance(from, new_from)?;
        self.set_balance(to, new_to)?;

        self.accrued_fees = self
            .accrued_fees
            .checked_add(fee)
            .ok_or(VaultError::Overflow)?;
        Ok(())
    }

    pub fn sweep_fees(&mut self, _caller: u32) -> Result<u64, VaultError> {
        // BUG(zkaudit-3): missing caller == owner check
        let fees = self.accrued_fees;
        self.accrued_fees = 0;
        Ok(fees)
    }

    pub fn balance_of(&self, user: u32) -> u64 {
        self.get_balance(user)
    }

    pub fn accrued_fees(&self) -> u64 {
        self.accrued_fees
    }

    pub fn total_assets(&self) -> u64 {
        self.balances.sum().saturating_add(self.accrued_fees)
    }
}
