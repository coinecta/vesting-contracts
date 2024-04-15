use aiken/transaction.{Mint, ScriptContext, Spend, WithdrawFrom}
use vesting_contracts/linear_vesting/mint.{LinearVestingMintRedeemer, mint}
use vesting_contracts/linear_vesting/spend.{
  LinearVestingDatum, LinearVestingSpendRedeemer, spend,
}
use vesting_contracts/linear_vesting/withdrawal.{withdraw}

validator {
  fn linear_spend(
    datum: LinearVestingDatum,
    redeemer: LinearVestingSpendRedeemer,
    ctx: ScriptContext,
  ) -> Bool {
    when ctx.purpose is {
      Spend(output_reference) -> spend(output_reference, datum, redeemer, ctx)
      _ -> False
    }
  }

  fn linear_mint(
    redeemer: LinearVestingMintRedeemer,
    ctx: ScriptContext,
  ) -> Bool {
    when ctx.purpose is {
      Mint(_) -> mint(redeemer, ctx)
      WithdrawFrom(_) -> withdraw(redeemer, ctx)
      _ -> False
    }
  }
}
