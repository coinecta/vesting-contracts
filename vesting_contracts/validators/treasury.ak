use aiken/dict.{has_key}
use aiken/transaction.{
  InlineDatum, Input, Output, OutputReference, ScriptContext, Spend, Transaction,
  find_input, find_script_outputs,
}
use aiken/transaction/credential.{Address, Inline, ScriptCredential}
use aiken/transaction/value.{Value, merge, negate, zero}
use sundae/multisig.{satisfied}
use vesting_contracts/datums.{TreasuryDatum}
use vesting_contracts/merkle_tree_blake2b.{Proof, Root, from_hash, is_member}
use vesting_contracts/redeemers.{
  Claim, ClaimEntry, Reclaim, TreasuryRedeemer, serialise_entry,
}

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

fn claim(
  treasury_output_reference: OutputReference,
  claim_proof: Proof<ClaimEntry>,
  claim_entry: ClaimEntry,
  tx: Transaction,
) -> Bool {
  expect Some(Input(_, treasury_input)) =
    find_input(tx.inputs, treasury_output_reference)
  expect Address(ScriptCredential(treasury_script_hash), _) =
    treasury_input.address
  expect InlineDatum(treasury_input_data) = treasury_input.datum
  expect [treasury_output] =
    find_script_outputs(tx.outputs, treasury_script_hash)
  expect InlineDatum(treasury_output_data) = treasury_output.datum
  expect current_treasury_datum: TreasuryDatum = treasury_input_data
  expect new_treasury_datum: TreasuryDatum = treasury_output_data
  and {
    (treasury_input.address == treasury_output.address)?,
    verify_value(claim_entry, treasury_input.value, treasury_output.value)?,
    verify_datum(current_treasury_datum, new_treasury_datum)?,
    verify_claim(
      claim_proof,
      claim_entry,
      from_hash(current_treasury_datum.claimant_tree),
      from_hash(new_treasury_datum.claimant_tree),
    )?,
    verify_vesting_program(current_treasury_datum, tx)?,
    satisfied(
      claim_entry.claimant,
      tx.extra_signatories,
      tx.validity_range,
      tx.withdrawals,
    )?,
  }
}

fn verify_vesting_program(datum: TreasuryDatum, tx: Transaction) -> Bool {
  tx.withdrawals
    |> has_key(Inline(ScriptCredential(datum.vesting_program)))
}

fn verify_datum(input_datum: TreasuryDatum, output_datum: TreasuryDatum) -> Bool {
  output_datum == TreasuryDatum {
    ..input_datum,
    claimant_tree: output_datum.claimant_tree,
  }
}

fn verify_value(
  claim_entry: ClaimEntry,
  input_value: Value,
  output_value: Value,
) -> Bool {
  let claimed_value =
    claim_entry.vesting_value |> merge(claim_entry.direct_value) |> negate()
  let expected_output_value = input_value |> merge(claimed_value)
  expected_output_value == output_value
}

fn verify_claim(
  claim_proof: Proof<ClaimEntry>,
  claim_entry: ClaimEntry,
  current_root: Root,
  new_root: Root,
) -> Bool {
  let emptied_entry =
    ClaimEntry { ..claim_entry, direct_value: zero(), vesting_value: zero() }
  and {
    is_member(current_root, claim_entry, claim_proof, serialise_entry),
    is_member(new_root, emptied_entry, claim_proof, serialise_entry),
  }
}

fn reclaim(datum: TreasuryDatum, tx: Transaction) -> Bool {
  satisfied(
    datum.owner,
    tx.extra_signatories,
    tx.validity_range,
    tx.withdrawals,
  )
}
