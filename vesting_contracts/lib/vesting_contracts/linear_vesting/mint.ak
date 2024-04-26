use aiken/bytearray.{concat, drop, take}
use aiken/cbor.{serialise}
use aiken/dict.{Dict, from_list, get, size, to_list}
use aiken/hash.{Blake2b_224, Hash, blake2b_256}
use aiken/list.{all, filter, indexed_map, length}
use aiken/math.{abs}
use aiken/transaction.{
  Output, OutputReference, ScriptContext, find_script_outputs,
}
use aiken/transaction/credential.{Script}
use aiken/transaction/value.{
  AssetName, PolicyId, from_minted_value, to_dict, tokens,
}
use vesting_contracts/datums.{reference_prefix, user_nft_prefix}
use vesting_contracts/merkle_tree_blake2b.{Proof}
use vesting_contracts/redeemers.{ClaimEntry}
use vesting_contracts/util.{find_script_inputs}

pub type LinearVestingMintRedeemer {
  Vest
  Claim { claim_proof: Proof<ClaimEntry>, claim_entry: ClaimEntry }
}

//This structure is used to build unique asset names for multiple outputs
type VestingNFTSignature {
  output_reference: OutputReference,
  index: Int,
}

pub fn mint(
  policy_id: PolicyId,
  treasury_hash: Hash<Blake2b_224, Script>,
  redeemer: LinearVestingMintRedeemer,
  ctx: ScriptContext,
) -> Bool {
  when redeemer is {
    Vest -> True
    Claim(_, _) -> claim(treasury_hash, policy_id, ctx)
  }
}

fn claim(
  treasury_hash: Hash<Blake2b_224, Script>,
  policy_id: PolicyId,
  ctx: ScriptContext,
) -> Bool {
  expect [treasury_input] =
    find_script_inputs(ctx.transaction.inputs, treasury_hash)
  expect Some(minted_burned_assets) =
    from_minted_value(ctx.transaction.mint) |> to_dict |> get(policy_id)
  let (burned_assets, minted_assets) = split_mints_burns(minted_burned_assets)
  let vesting_outputs = find_script_outputs(ctx.transaction.outputs, policy_id)
  let signature_template =
    VestingNFTSignature {
      output_reference: treasury_input.output_reference,
      index: 0,
    }
  //Due to the use of cip-68 we expect double the amount of vesting outputs as minted assets
  let expected_minted_assets = length(vesting_outputs) * 2
  and {
    (size(burned_assets) == 0)?,
    (size(minted_assets) == expected_minted_assets)?,
    verify_cip68_pairs(minted_assets)?,
    verify_split_vesting(vesting_outputs, signature_template, policy_id)?,
  }
}

fn split_mints_burns(
  minted_burned_assets: Dict<AssetName, Int>,
) -> (Dict<AssetName, Int>, Dict<AssetName, Int>) {
  let asset_list = minted_burned_assets |> to_list()
  (
    from_list(asset_list |> filter(fn(a) { a.2nd < 0 }), bytearray.compare),
    from_list(asset_list |> filter(fn(a) { a.2nd > 0 }), bytearray.compare),
  )
}

fn verify_cip68_pairs(minted_assets: Dict<AssetName, Int>) -> Bool {
  let reference_nfts =
    minted_assets
      |> to_list()
      |> filter(fn(a) { take(a.1st, 4) == reference_prefix })
  let reference_match =
    reference_nfts
      |> all(
          fn(a) {
            expect Some(user_nft_amount) =
              minted_assets |> get(concat(user_nft_prefix, drop(a.1st, 4)))
            let absolute_amount = abs(a.2nd)
            expect absolute_amount == 1
            a.2nd == user_nft_amount
          },
        )
  let expected_nft_count = length(reference_nfts) * 2
  and {
    reference_match?,
    (expected_nft_count == size(minted_assets))?,
  }
}

fn verify_split_vesting(
  vesting_outputs: List<Output>,
  signature_template: VestingNFTSignature,
  policy_id: PolicyId,
) -> Bool {
  vesting_outputs
    |> indexed_map(
        fn(i, vo) {
          let signature = VestingNFTSignature { ..signature_template, index: i }
          verify_vesting_output(vo, signature, policy_id)
        },
      )
    |> all(identity)
}

fn verify_vesting_output(
  vo: Output,
  signature: VestingNFTSignature,
  policy_id: PolicyId,
) -> Bool {
  let serialised_signature = blake2b_256(serialise(signature))
  let correct_asset_name =
    reference_prefix |> concat(take(serialised_signature, 28))
  let tokens = vo.value |> tokens(policy_id)
  expect Some(1) = get(tokens, correct_asset_name)
  size(tokens) == 1
}
