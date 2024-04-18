use aiken/time.{PosixTime}
use aiken/transaction.{Datum, InlineDatum, OutputReference, ScriptContext}

pub type LinearVestingSpendRedeemer {
  Vest
  Split
  Combine
}

pub type LinearVestingParameters {
  start_time: PosixTime,
  vest_frequency: PosixTime,
  vest_periods: Int,
}

pub type LinearVestingDatum {
  vesting_nft: ByteArray,
  vesting_parameters: LinearVestingParameters,
}

pub fn extract_linear_vesting_datum(datum: Datum) -> LinearVestingDatum {
  expect InlineDatum(inline) = datum
  expect linear_vesting_datum: LinearVestingDatum = inline
  linear_vesting_datum
}

pub fn spend(
  output_reference: OutputReference,
  datum: LinearVestingDatum,
  redeemer: LinearVestingSpendRedeemer,
  ctx: ScriptContext,
) -> Bool {
  when redeemer is {
    Vest -> vest(output_reference, datum, ctx)
    Split -> False
    Combine -> False
  }
}

fn vest(
  _output_reference: OutputReference,
  _datum: LinearVestingDatum,
  _ctx: ScriptContext,
) -> Bool {
  True
}
