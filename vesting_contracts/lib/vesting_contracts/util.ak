use aiken/hash.{Blake2b_224, Hash}
use aiken/list.{filter}
use aiken/transaction.{Input}
use aiken/transaction/credential.{Script, ScriptCredential}
use aiken/transaction/value.{Value, from_lovelace}

pub fn min_utxo() -> Value {
  from_lovelace(2_000_000)
}

//Similar to find_script_outputs, filters Inputs based on script hash
pub fn find_script_inputs(
  inputs: List<Input>,
  script_hash: Hash<Blake2b_224, Script>,
) -> List<Input> {
  inputs
    |> filter(
        fn(i) {
          ScriptCredential(script_hash) == i.output.address.payment_credential
        },
      )
}
