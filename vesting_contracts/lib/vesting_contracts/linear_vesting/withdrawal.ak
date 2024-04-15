use aiken/transaction.{ScriptContext}
use vesting_contracts/linear_vesting/mint.{Claim, LinearVestingMintRedeemer}

pub fn withdraw(redeemer: LinearVestingMintRedeemer, ctx: ScriptContext) -> Bool {
  when redeemer is {
    Claim -> True
    _ -> False
  }
}
