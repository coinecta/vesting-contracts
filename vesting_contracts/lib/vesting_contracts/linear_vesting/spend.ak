use aiken/time.{PosixTime}
use aiken/transaction.{OutputReference, ScriptContext}

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
  vesting_parameters: LinearVestingParameters,
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
  output_reference: OutputReference,
  datum: LinearVestingDatum,
  ctx: ScriptContext,
) -> Bool {
  True
}
