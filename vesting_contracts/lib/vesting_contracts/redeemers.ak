use aiken/cbor.{serialise}
use aiken/transaction/value.{Value}
use sundae/multisig.{MultisigScript}
use vesting_contracts/merkle_tree_blake2b.{Proof}

pub type ClaimEntry {
  claimant: MultisigScript,
  vesting_value: Value,
  direct_value: Value,
}

pub fn serialise_entry(claim_entry: ClaimEntry) -> ByteArray {
  serialise(claim_entry)
}

pub type TxType {
  Claim { claim_proof: Proof<ClaimEntry>, claim_entry: ClaimEntry }
  Reclaim
}

pub type TreasuryRedeemer {
  tx_type: TxType,
}
