use aiken/hash.{Blake2b_224, Blake2b_256, Hash}
use aiken/transaction/credential.{Script}
use sundae/multisig.{MultisigScript}
use vesting_contracts/redeemers.{ClaimEntry}

pub type TreasuryDatum {
  owner: MultisigScript,
  claimant_tree: Hash<Blake2b_256, ClaimEntry>,
  vesting_program: Hash<Blake2b_224, Script>,
}
