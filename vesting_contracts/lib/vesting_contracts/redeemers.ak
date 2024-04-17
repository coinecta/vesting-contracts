use aiken/cbor.{serialise}
use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{Script}
use aiken/transaction/value.{Value}
use sundae/multisig.{MultisigScript}
use vesting_contracts/merkle_tree_blake2b.{Proof}

pub type ClaimEntry {
  claimant: MultisigScript,
  vesting_value: Value,
  direct_value: Value,
  vesting_parameters: ByteArray,
  vesting_program: Hash<Blake2b_224, Script>,
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
