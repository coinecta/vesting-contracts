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

//Verify that the validator identified by the vesting_hash is present in the withdrawals of this tx
pub fn verify_vesting_program(vesting_hash: ByteArray, tx: Transaction) -> Bool {
  tx.withdrawals
    |> has_key(Inline(ScriptCredential(vesting_hash)))
}

//Verify that the output datum is identical to the input datum with the merkle tree root replaced
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

//Verify that the claim is present in the merkle tree and that the new tree contains the
//same tree but with the claim emptied
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

//Ensure the reclaim tx is signed by the multisigscript owner of the treasury
//TODO: set and verify a minimum time
pub fn reclaim(datum: TreasuryDatum, tx: Transaction) -> Bool {
  satisfied(
    datum.owner,
    tx.extra_signatories,
    tx.validity_range,
    tx.withdrawals,
  )
}

//User takes their claim from treasury
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
  //We expect only 1 treasury in the outputs
  expect [treasury_output] =
    find_script_outputs(tx.outputs, treasury_script_hash)
  //Cast datums to correct type
  let current_treasury_datum = extract_treasury_datum(treasury_input.datum)
  let new_treasury_datum = extract_treasury_datum(treasury_output.datum)

  and {
    //Treasury address remains the same
    (treasury_input.address == treasury_output.address)?,
    //Treasury value in output is correct
    verify_value(claim_entry, treasury_input.value, treasury_output.value)?,
    //Treasury datum in output is correct
    verify_datum(current_treasury_datum, new_treasury_datum)?,
    //Claim is present in merkle tree and output merkle tree
    verify_claim(
      claim_proof,
      claim_entry,
      from_hash(current_treasury_datum.claimant_tree),
      from_hash(new_treasury_datum.claimant_tree),
    )?,
    //The vesting program defined in the claim is present in withdrawals
    verify_vesting_program(claim_entry.vesting_program, tx)?,
    //The transaction is signed by the claimant
    satisfied(
      claim_entry.claimant,
      tx.extra_signatories,
      tx.validity_range,
      tx.withdrawals,
    )?,
  }
}
