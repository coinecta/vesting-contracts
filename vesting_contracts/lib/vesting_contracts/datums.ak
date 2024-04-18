use aiken/hash.{Blake2b_256, Hash}
use aiken/transaction.{Datum, InlineDatum}
use sundae/multisig.{MultisigScript}
use vesting_contracts/redeemers.{ClaimEntry}

pub type TreasuryDatum {
  owner: MultisigScript,
  claimant_tree: Hash<Blake2b_256, ClaimEntry>,
}

pub fn extract_treasury_datum(on_chain_datum: Datum) -> TreasuryDatum {
  expect InlineDatum(inline_datum) = on_chain_datum
  expect casted_datum: TreasuryDatum = inline_datum
  casted_datum
}
