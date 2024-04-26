use aiken/time.{PosixTime}
use aiken/transaction.{
  Datum, InlineDatum, OutputReference, ScriptContext, find_input,
}
use aiken/transaction/credential.{Address, ScriptCredential}
use vesting_contracts/treasury.{verify_vesting_program}

pub type LinearVestingSpendRedeemer {
  Vest
}

pub type LinearVestingParameters {
  //The time that value in the vesting utxo starts vesting
  start_time: PosixTime,
  //At which interval the value vests
  vest_frequency: PosixTime,
  //Number of vesting periods left (So after vest_periods*vest_frequency+start_time all assets are vested)
  vest_periods: Int,
  //Cliff time, tokens are not vested before this time
  cliff_time: PosixTime,
}

pub type LinearVestingDatum {
  vesting_parameters: LinearVestingParameters,
}

pub type CIP68Datum {
  //Metadata fields holding name, img etc for the stake nft following CIP-25
  metadata: List<(ByteArray, ByteArray)>,
  //Following on chain metadata standard in CIP-68
  version: Int,
  //Data defining the time the assets are to be locked and how to unlock
  extra: LinearVestingDatum,
}

pub fn extract_linear_vesting_datum(datum: Datum) -> CIP68Datum {
  expect InlineDatum(inline) = datum
  expect linear_vesting_datum: CIP68Datum = inline
  linear_vesting_datum
}

pub fn spend(
  output_reference: OutputReference,
  _redeemer: LinearVestingSpendRedeemer,
  ctx: ScriptContext,
) -> Bool {
  vest(output_reference, ctx)
}

//The logic is based on multiple inputs and multiple outputs. To avoid recalculating a lot
//we calculate it once in a withdrawal script and only check the presence of the script here.
fn vest(output_reference: OutputReference, ctx: ScriptContext) -> Bool {
  expect Some(input) = find_input(ctx.transaction.inputs, output_reference)
  expect Address(ScriptCredential(vesting_hash), _) = input.output.address
  verify_vesting_program(vesting_hash, ctx.transaction)
}
