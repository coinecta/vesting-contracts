use aiken/transaction.{ScriptContext, Spend}
use vesting_contracts/datums.{TreasuryDatum}
use vesting_contracts/redeemers.{Claim, Reclaim, TreasuryRedeemer}
use vesting_contracts/treasury.{claim, reclaim}

validator {
  fn treasury(
    datum: TreasuryDatum,
    redeemer: TreasuryRedeemer,
    ctx: ScriptContext,
  ) -> Bool {
    when ctx.purpose is {
      Spend(output_reference) ->
        when redeemer.tx_type is {
          Claim(claim_proof, claim_entry) ->
            claim(output_reference, claim_proof, claim_entry, ctx.transaction)
          Reclaim -> reclaim(datum, ctx.transaction)
        }
      _ -> False
    }
  }
}
