#import "template.typ": *

#let HLR = (
  "1": (
    title: [Unvested tokens need to start vested at a certain point in time],
    description: [It should be possible to control when tokens locked in the contract start being vested, to support preventing tokens coming into circulation before for example an IDO.],
  ),
  "2": (
    title: [Tokens need to vest at a certain linear rate],
    description: [Once the initial time of vesting (#link(<HLR1>)[HLR1]) has been reached the unvested tokens locked in the contract should be vested gradually at a specific linear rate, such that every X amount of time Y% of the initially unvested tokens are to be vested.],
  ),
  "3": (
    title: [Vested tokens are to be claimed by the user with a vesting NFT],
    description: [Those tokens that are vested according to (#link(<HLR1>)[HLR1]) and (#link(<HLR2>)[HLR2]), are to be claimed by a unique NFT. This allows the unvested tokens to be transferrable even though they are still locked.],
  ),
  "4": (
    title: [The vesting NFT should be claimed by the user],
    description: [The vesting NFT described in (#link(<HLR3>)[HLR3]) is not airdropped to eligible users but must be claimed/minted by the user. Preventing high ADA costs incurring on the project running the vesting setup.],
  ),
  "5": (
    title: [The admin should be able to specify how much each user can claim],
    description: [When the user claims their vesting NFT the amount available to them to lock should be defined by the admin of the protocol. The admin also decides the parameters such as vesting rate.],
  ),
  "6": (
    title: [The user can decide how much to lock behind a vesting NFT, so their allocation can be split into multiple vesting NFT's],
    description: [When the user claims their vesting NFT they can decide to lock a smaller amount than their full allocation, giving them the option to divide their allocation into smaller amounts.],
  ),
  "7": (
    title: [The admin can remove unclaimed tokens after a certain time has passed.],
    description: [If any user does not claim their vesting NFT in time the admin can recover the unclaimed tokens, so they can be used for other purposes.]
  ),
  "8": (
    title: [If a user claims tokens after initial release time has passed vested assets are released along with vesting NFT],
    description: [If a user claims their vesting NFT after the initial release time has passed (#link(<HLR1>)[HLR1]) they will receive vested tokens following (#link(<HLR2>)[HLR2]) along with the vesting NFT. If all tokens are vested no vesting NFT is minted and the user receives all tokens.]
  )
)

#let actors = (
  "admin": (
    title: "Admin",
    description: "Admin (wallet) bootstrapping the protocol",
    interaction: ((
      index: "treasury",
      transaction: "Spend: Bootstrap"
    ),)
  ),
  "treasury": (
    title: "Vesting Treasury",
    description: "Allocation smart contract containing the allocation for all users in a merkle tree",
    interaction: ((
      index: "vesting",
      transaction: "Spend: Claim"
      ),
      (
        index: "user",
        transaction: "Spend: Claim"
      ),
      (
        index: "admin",
        transaction: "Spend: Reclaim"
      ))
  ),
  "vesting": (
    title: "Vesting",
    description: "Vested contract holding unvested tokens for the user",
    interaction: ((
      index: "user",
      transaction: "Spend: Vest"
    ),)
  ),
  "user": (
    title: "User",
    description: "User (wallet) interacting with the protocol",
    interaction: ()
  ),
  "linear_vest": (
    title: "Linear Vesting",
    description: "Contract controlling the correct settings for a linear vesting lock",
    interaction: ((
      index: "vesting",
      transaction: "Withdrawal: Claim"
    ),)),
    "linear_vest_mint": (
    title: "Linear Vesting Mint Policy",
    description: "Contract controlling the correct minting and burning of vesting nft's",
    interaction: ((
      index: "user",
      transaction: "Mint: Claim"
    ),))
  )
)

#show_intro(title: "Coinecta Vesting Contracts", body: "Vesting contracts are a way to guarantee tokens are only released into circulation at a certain rate. This can be beneficial in multiple scenarios, for example if tokens are sold during a presale event with a price under the targeted IDO price any participant in the presale has an unfair advantage and could negatively affect the market.")

#show_hlr(hlr: HLR, body: "For Coinecta we have the following High Level Requirements (HLR) that we would like the contracts to fulfill.")

#show_overview(actors: actors, body: "Test")
