use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction.{Mint, ScriptContext, Spend, WithdrawFrom}
use aiken/transaction/credential.{Script}
use vesting_contracts/linear_vesting/mint.{LinearVestingMintRedeemer, mint}
use vesting_contracts/linear_vesting/spend.{
  LinearVestingDatum, LinearVestingSpendRedeemer, spend,
}
use vesting_contracts/linear_vesting/withdrawal.{withdraw}

validator(treasury_hash: Hash<Blake2b_224, Script>) {
  fn linear_spend(
    _datum: LinearVestingDatum,
    redeemer: LinearVestingSpendRedeemer,
    ctx: ScriptContext,
  ) -> Bool {
    when ctx.purpose is {
      Spend(output_reference) -> spend(output_reference, redeemer, ctx)
      _ -> False
    }
  }

  //Both mint and withdrawfrom is covered by this validator (only 2 functions supported per validator)
  fn linear_mint(
    redeemer: LinearVestingMintRedeemer,
    ctx: ScriptContext,
  ) -> Bool {
    when ctx.purpose is {
      Mint(policy_id) -> mint(policy_id, treasury_hash, redeemer, ctx)
      WithdrawFrom(stake_credential) ->
        withdraw(stake_credential, treasury_hash, redeemer, ctx)
      _ -> False
    }
  }
}
