use aiken/hash.{Blake2b_256, Hash}
use sundae/multisig.{MultisigScript}
use vesting_contracts/redeemers.{ClaimEntry}

pub type TreasuryDatum {
  owner: MultisigScript,
  claimant_tree: Hash<Blake2b_256, ClaimEntry>,
}
