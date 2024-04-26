use aiken/cbor.{serialise}
use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{Script}
use aiken/transaction/value.{Value}
use sundae/multisig.{MultisigScript}
use vesting_contracts/merkle_tree_blake2b.{Proof}

pub type ClaimEntry {
  //Claimant which can perform the claim tx for this entry
  claimant: MultisigScript,
  //The value to be deposited into the vesting program
  vesting_value: Value,
  //Value the claimant can claim directly into their wallet
  direct_value: Value,
  //Serialised parameters for the vesting program
  //Serialised to support different structures for future vesting program types
  vesting_parameters: ByteArray,
  //The hash of the vesting program validator
  vesting_program: Hash<Blake2b_224, Script>,
}

//Wrapper needed to feed to merkle tree functions for serialising ClaimEntry
pub fn serialise_entry(claim_entry: ClaimEntry) -> ByteArray {
  serialise(claim_entry)
}

pub type TreasuryRedeemer {
  Claim { claim_proof: Proof<ClaimEntry>, claim_entry: ClaimEntry }
  Reclaim
}
