use aiken/dict.{has_key}
use aiken/transaction.{
  Input, Output, OutputReference, Transaction, find_input, find_script_outputs,
}
use aiken/transaction/credential.{Address, Inline, ScriptCredential}
use aiken/transaction/value.{Value, merge, negate, zero}
use sundae/multisig.{satisfied}
use vesting_contracts/datums.{TreasuryDatum, extract_treasury_datum}
use vesting_contracts/merkle_tree_blake2b.{Proof, Root, from_hash, is_member}
use vesting_contracts/redeemers.{ClaimEntry, serialise_entry}

pub fn verify_vesting_program(claim_entry: ClaimEntry, tx: Transaction) -> Bool {
  tx.withdrawals
    |> has_key(Inline(ScriptCredential(claim_entry.vesting_program)))
}

pub fn verify_datum(
  input_datum: TreasuryDatum,
  output_datum: TreasuryDatum,
) -> Bool {
  output_datum == TreasuryDatum {
    ..input_datum,
    claimant_tree: output_datum.claimant_tree,
  }
}

pub fn verify_value(
  claim_entry: ClaimEntry,
  input_value: Value,
  output_value: Value,
) -> Bool {
  let claimed_value =
    claim_entry.vesting_value |> merge(claim_entry.direct_value) |> negate()
  let expected_output_value = input_value |> merge(claimed_value)
  expected_output_value == output_value
}

pub fn verify_claim(
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

pub fn reclaim(datum: TreasuryDatum, tx: Transaction) -> Bool {
  satisfied(
    datum.owner,
    tx.extra_signatories,
    tx.validity_range,
    tx.withdrawals,
  )
}

pub fn claim(
  treasury_output_reference: OutputReference,
  claim_proof: Proof<ClaimEntry>,
  claim_entry: ClaimEntry,
  tx: Transaction,
) -> Bool {
  expect Some(Input(_, treasury_input)) =
    find_input(tx.inputs, treasury_output_reference)
  expect Address(ScriptCredential(treasury_script_hash), _) =
    treasury_input.address
  expect [treasury_output] =
    find_script_outputs(tx.outputs, treasury_script_hash)
  let current_treasury_datum = extract_treasury_datum(treasury_input.datum)
  let new_treasury_datum = extract_treasury_datum(treasury_output.datum)
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
    verify_vesting_program(claim_entry, tx)?,
    satisfied(
      claim_entry.claimant,
      tx.extra_signatories,
      tx.validity_range,
      tx.withdrawals,
    )?,
  }
}
