use aiken/cbor.{serialise}
use aiken/hash.{Blake2b_224, Hash}
use aiken/list.{all, foldl, map}
use aiken/transaction.{Output, ScriptContext, find_script_outputs}
use aiken/transaction/credential.{
  Inline, Script, ScriptCredential, StakeCredential,
}
use aiken/transaction/value.{
  Value, flatten_with, from_asset, from_lovelace, merge, negate, zero,
}
use vesting_contracts/datums.{extract_treasury_datum}
use vesting_contracts/linear_vesting/mint.{Claim, LinearVestingMintRedeemer}
use vesting_contracts/linear_vesting/spend.{extract_linear_vesting_datum}
use vesting_contracts/merkle_tree_blake2b.{Proof, from_hash}
use vesting_contracts/redeemers.{ClaimEntry}
use vesting_contracts/treasury.{verify_claim}

pub fn withdraw(
  linear_vesting_stake_credential: StakeCredential,
  treasury_hash: Hash<Blake2b_224, Script>,
  redeemer: LinearVestingMintRedeemer,
  ctx: ScriptContext,
) -> Bool {
  when redeemer is {
    Claim(claim_proof, claim_entry) ->
      claim(
        linear_vesting_stake_credential,
        treasury_hash,
        claim_proof,
        claim_entry,
        ctx,
      )
    _ -> False
  }
}

fn claim(
  linear_vesting_stake_credential: StakeCredential,
  treasury_hash: Hash<Blake2b_224, Script>,
  claim_proof: Proof<ClaimEntry>,
  claim_entry: ClaimEntry,
  ctx: ScriptContext,
) -> Bool {
  expect [treasury_input] =
    find_script_outputs(
      map(ctx.transaction.inputs, fn(i) { i.output }),
      treasury_hash,
    )
  expect [treasury_output] =
    find_script_outputs(ctx.transaction.outputs, treasury_hash)
  let treasury_input_datum = extract_treasury_datum(treasury_input.datum)
  let treasury_output_datum = extract_treasury_datum(treasury_output.datum)

  expect Inline(ScriptCredential(linear_vesting_hash)) =
    linear_vesting_stake_credential
  let linear_vesting_outputs =
    find_script_outputs(ctx.transaction.outputs, linear_vesting_hash)
  and {
    verify_claim(
      claim_proof,
      claim_entry,
      from_hash(treasury_input_datum.claimant_tree),
      from_hash(treasury_output_datum.claimant_tree),
    )?,
    verify_vesting_parameters(
      claim_entry.vesting_parameters,
      linear_vesting_outputs,
    )?,
    verify_vesting_value(
      claim_entry.vesting_value,
      linear_vesting_outputs,
      linear_vesting_hash,
    )?,
  }
}

fn verify_vesting_parameters(
  vesting_parameters: ByteArray,
  linear_vesting_outputs,
) -> Bool {
  linear_vesting_outputs
    |> all(
        fn(o) {
          let linear_vesting_datum = extract_linear_vesting_datum(o.datum)
          serialise(linear_vesting_datum.vesting_parameters) == vesting_parameters
        },
      )
}

fn verify_vesting_value(
  vesting_value: Value,
  lv_outputs: List<Output>,
  vesting_mint_policy: Hash<Blake2b_224, Script>,
) -> Bool {
  let actual_vesting_value =
    lv_outputs
      |> foldl(
          zero(),
          fn(lv_output, total) {
            merge(
              total,
              lv_output.value
                |> flatten_with(
                    fn(policy_id, asset_name, amount) {
                      if policy_id != vesting_mint_policy {
                        Some(from_asset(policy_id, asset_name, amount))
                      } else {
                        None
                      }
                    },
                  )
                |> foldl(
                    negate(from_lovelace(2_000_000)),
                    fn(v, t) { merge(v, t) },
                  ),
            )
          },
        )
  actual_vesting_value == vesting_value
}
