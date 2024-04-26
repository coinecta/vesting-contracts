use aiken/hash.{Blake2b_256, Hash}
use aiken/transaction.{Datum, InlineDatum}
use sundae/multisig.{MultisigScript}
use vesting_contracts/redeemers.{ClaimEntry}

//Prefix of the reference nft asset id according to CIP-68
pub const reference_prefix = #"000643b0"

//Prefix of the nft asset id according to CIP-68
pub const user_nft_prefix = #"000de140"

pub type TreasuryDatum {
  //Owner of the treasury which can perform the reclaim tx
  owner: MultisigScript,
  //Root of the merkle tree holding the claims
  claimant_tree: Hash<Blake2b_256, ClaimEntry>,
}

//Cast a datum to a TreasuryDatum
pub fn extract_treasury_datum(on_chain_datum: Datum) -> TreasuryDatum {
  expect InlineDatum(inline_datum) = on_chain_datum
  expect casted_datum: TreasuryDatum = inline_datum
  casted_datum
}
