use aiken/transaction.{ScriptContext}

pub type LinearVestingMintRedeemer {
  Vest
  Split
  Combine
  Claim
}

pub fn mint(redeemer: LinearVestingMintRedeemer, ctx: ScriptContext) -> Bool {
  when redeemer is {
    Vest -> True
    Split -> True
    Combine -> True
    Claim -> True
  }
}
