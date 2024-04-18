use aiken/transaction.{ScriptContext}
use vesting_contracts/merkle_tree_blake2b.{Proof}
use vesting_contracts/redeemers.{ClaimEntry}

pub type LinearVestingMintRedeemer {
  Vest
  Split
  Combine
  Claim { claim_proof: Proof<ClaimEntry>, claim_entry: ClaimEntry }
}

pub fn mint(redeemer: LinearVestingMintRedeemer, _ctx: ScriptContext) -> Bool {
  when redeemer is {
    Vest -> True
    Split -> True
    Combine -> True
    Claim(_, _) -> True
  }
}
