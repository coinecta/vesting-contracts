use aiken/builtin.{b_data}
use aiken/cbor.{serialise}
use aiken/hash.{Blake2b_224, Hash}
use aiken/interval.{Finite}
use aiken/list.{all, at, foldl, map, push}
use aiken/math.{min}
use aiken/time.{PosixTime}
use aiken/transaction.{InlineDatum, Output, ScriptContext, find_script_outputs}
use aiken/transaction/credential.{
  Inline, Script, ScriptCredential, StakeCredential,
}
use aiken/transaction/value.{
  Value, flatten_with, from_asset, merge, negate, zero,
}
use vesting_contracts/datums.{extract_treasury_datum}
use vesting_contracts/linear_vesting/mint.{
  Claim, LinearVestingMintRedeemer, Vest,
}
use vesting_contracts/linear_vesting/spend.{
  LinearVestingDatum, LinearVestingParameters, extract_linear_vesting_datum,
}
use vesting_contracts/merkle_tree_blake2b.{Proof, from_hash}
use vesting_contracts/redeemers.{ClaimEntry}
use vesting_contracts/treasury.{verify_claim}
use vesting_contracts/util.{find_script_inputs, min_utxo}

pub fn withdraw(
  linear_vesting_stake_credential: StakeCredential,
  treasury_hash: Hash<Blake2b_224, Script>,
  redeemer: LinearVestingMintRedeemer,
  ctx: ScriptContext,
) -> Bool {
  expect Inline(ScriptCredential(linear_vesting_hash)) =
    linear_vesting_stake_credential
  when redeemer is {
    Claim(claim_proof, claim_entry) ->
      claim(linear_vesting_hash, treasury_hash, claim_proof, claim_entry, ctx)
    Vest -> vest(ctx, linear_vesting_hash)
  }
}

fn vest(ctx: ScriptContext, linear_vesting_hash: ByteArray) -> Bool {
  let linear_vesting_outputs =
    find_script_outputs(ctx.transaction.outputs, linear_vesting_hash)
  let linear_vesting_inputs =
    find_script_inputs(ctx.transaction.inputs, linear_vesting_hash)
      |> map(fn(i) { i.output })
  expect Finite(time) = ctx.transaction.validity_range.lower_bound.bound_type
  verify_vesting_inputs_outputs(
    linear_vesting_inputs,
    linear_vesting_outputs,
    linear_vesting_hash,
    time,
  )
}

//Verifies that vested value - redeemable value = vested value in output for all vesting
//inputs and outputs combined.
fn verify_vesting_inputs_outputs(
  vesting_inputs: List<Output>,
  vesting_outputs: List<Output>,
  linear_vesting_hash: ByteArray,
  time: PosixTime,
) -> Bool {
  //We use this input as an example to build our expected parameters
  expect Some(example_input) = vesting_inputs |> at(0)
  //Inputs should be on the same program, but might be on different stages of redeeming
  //so we use the parameters AFTER redeeming to ensure they all follow the same schedule
  let expected_vesting_parameters =
    vesting_parameters_after_redeem(
      time,
      extract_linear_vesting_datum(example_input.datum).extra.vesting_parameters,
    )
  //Sum up vested value in inputs
  let current_vested_value =
    vesting_inputs |> foldl(zero(), fn(v, t) { merge(vested_value(v), t) })
  //Sum up redeemable value in inputs
  let redeemable_value =
    vesting_inputs
      |> foldl(
          zero(),
          fn(v, t) {
            merge(redeemable_value(time, v, expected_vesting_parameters), t)
          },
        )
  //Expected vested value in outputs = vested value - redeemable value
  let expected_vested_value =
    current_vested_value |> merge(negate(redeemable_value))
  and {
    verify_vesting_parameters(
      serialise(expected_vesting_parameters),
      vesting_outputs,
    )?,
    verify_vesting_value(
      expected_vested_value,
      vesting_outputs,
      linear_vesting_hash,
    )?,
  }
}

//Calculates vested value
//TODO: filter out reference nft
fn vested_value(vesting_output: Output) -> Value {
  vesting_output.value |> merge(negate(min_utxo()))
}

//Calculates redeemable value for this output based on time
//NOTE: Fails if vesting parameters do not match to expected after redeem
fn redeemable_value(
  time: PosixTime,
  vesting_output: Output,
  expected_vesting_parameters: LinearVestingParameters,
) -> Value {
  let vesting_datum = extract_linear_vesting_datum(vesting_output.datum)
  let vp_after_redeem =
    vesting_parameters_after_redeem(
      time,
      vesting_datum.extra.vesting_parameters,
    )
  expect vp_after_redeem == expected_vesting_parameters
  let vested_value = vested_value(vesting_output)
  let redeemable_periods =
    vesting_datum.extra.vesting_parameters.vest_periods - vp_after_redeem.vest_periods
  vested_value
    |> flatten_with(
        fn(policy_id, asset_name, amount) {
          let redeemable_amount =
            amount * redeemable_periods / vesting_datum.extra.vesting_parameters.vest_periods
          if redeemable_amount > 0 {
            Some(from_asset(policy_id, asset_name, redeemable_amount))
          } else {
            None
          }
        },
      )
    |> foldl(zero(), fn(v, t) { merge(v, t) })
}

//Transform vesting parameters to how they should be after redeem at this time
fn vesting_parameters_after_redeem(
  time: PosixTime,
  vesting_parameters: LinearVestingParameters,
) -> LinearVestingParameters {
  if time > vesting_parameters.cliff_time {
    let redeemable_periods =
      min(
        vesting_parameters.vest_periods,
        ( time - vesting_parameters.start_time ) / vesting_parameters.vest_frequency,
      )
    LinearVestingParameters {
      ..vesting_parameters,
      vest_periods: vesting_parameters.vest_periods - redeemable_periods,
      start_time: vesting_parameters.start_time + redeemable_periods * vesting_parameters.vest_frequency,
    }
  } else {
    vesting_parameters
  }
}

fn claim(
  linear_vesting_hash: ByteArray,
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

  let linear_vesting_outputs =
    find_script_outputs(ctx.transaction.outputs, linear_vesting_hash)
  expect Some(example_output) = linear_vesting_outputs |> at(0)
  expect claim_vesting_parameters: LinearVestingParameters =
    b_data(claim_entry.vesting_parameters)
  let linear_vesting_inputs =
    push(
      find_script_inputs(ctx.transaction.inputs, linear_vesting_hash)
        |> map(fn(o) { o.output }),
      Output {
        ..example_output,
        value: min_utxo() |> merge(claim_entry.vesting_value),
        datum: InlineDatum(
          LinearVestingDatum { vesting_parameters: claim_vesting_parameters },
        ),
      },
    )
  expect Finite(time) = ctx.transaction.validity_range.lower_bound.bound_type
  and {
    verify_claim(
      claim_proof,
      claim_entry,
      from_hash(treasury_input_datum.claimant_tree),
      from_hash(treasury_output_datum.claimant_tree),
    )?,
    verify_vesting_inputs_outputs(
      linear_vesting_inputs,
      linear_vesting_outputs,
      linear_vesting_hash,
      time,
    ),
  }
}

//Verify that all outputs have the expected parameters
fn verify_vesting_parameters(
  vesting_parameters: ByteArray,
  linear_vesting_outputs: List<Output>,
) -> Bool {
  linear_vesting_outputs
    |> all(
        fn(o) {
          let linear_vesting_datum = extract_linear_vesting_datum(o.datum)
          serialise(linear_vesting_datum.extra.vesting_parameters) == vesting_parameters
        },
      )
}

//Verify that vested value in outputs matches expected vesting value
//TODO: refactor to use vested_value function
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
                |> foldl(negate(min_utxo()), fn(v, t) { merge(v, t) }),
            )
          },
        )
  actual_vesting_value == vesting_value
}
