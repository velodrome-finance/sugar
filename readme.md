# Velodrome Sugar 🍭

Sugar comes with contracts to help working with Velodrome Finance data!

## How come?!

The idea is pretty simple, instead of relying on our API for a structured
data set of liquidity pool data, these contracts can be called in an
efficient way to directly fetch the same data off-chain.

What normally would require:
  1. fetching the number of liquidity pools
  2. querying every pool address at it's index
  3. querying pool tokens data
  4. querying gauge addresses and reward rate

Takes a single call with _sugar_!

More importantly, the response can be paginated.

Main goals of this little project are:
  * to maximize the developers UX of working with our protocol
  * simplify complexity
  * document and test everything

## But how?

On-chain data is organized for transaction cost and efficiency. We think
we can hide a lot of the complexity by leveraging `structs` to present the data
and normalize it based on it's relevancy.

## Usage

Below is the list of datasets we support.

### Liquidity Pools Data

`LpSugar.vy` is deployed at `0x90b18D906aa461a45229877469eD4c6A41c31Da6`

It allows fetching on-chain pools data.
The returned data/struct of type `Lp` values represent:

 * `lp` - pool contract address
 * `symbol` - pool symbol
 * `decimals` - pool decimals
 * `total_supply` - pool tokens supply
 * `nft` - NFT position manager on v3 pools, empty address on v2 pools
 * `type` - tick spacing on v3 pools, 0/-1 for stable/volatile on v2 pools
 * `tick` - current tick on v3 pools, 0 on v2 pools
 * `price` - pool price on v3 pools, 0 on v2 pools
 * `token0` - pool 1st token address
 * `reserve0` - pool 1st token reserves (nr. of tokens in the contract)
 * `token1` - pool 2nd token address
 * `reserve1` - pool 2nd token reserves (nr. of tokens in the contract)
 * `gauge` - pool gauge address
 * `gauge_total_supply` - pool staked tokens (less/eq than/to pool total supply)
 * `gauge_alive` - indicates if the gauge is still active
 * `fee` - pool gauge fees contract address
 * `bribe` - pool gauge bribes contract address
 * `factory` - pool factory address
 * `emissions` - pool emissions (per second)
 * `emissions_token` - pool emissions token address
 * `pool_fee` - pool swap fee (percentage)
 * `unstaked_fee` - unstaked fee percentage on v3 pools, 0 on v2 pools
 * `token0_fees` - current epoch token0 accrued fees (next week gauge fees)
 * `token1_fees` - current epoch token1 accrued fees (next week gauge fees)
 * `alm_vault` - ALM vault address on v3 if it exists, empty address on v2
 * `alm_reserve0` - ALM vault token0 reserves on v3, 0 on v2
 * `alm_reserve1` - ALM vault token1 reserves on v3, 0 on v2
 * `positions` - a list of account pool position data, it is a struct of type `Position` with the following values:
    * `id` - NFT ID on v3 pools, 0 on v2 pools
    * `manager` - NFT position manager on v3 pools, router on v2 pools
    * `liquidity` - liquidity value on v3, deposited LP tokens on v2
    * `staked` - 0/1 for staked/unstaked state on v3, amount of staked tokens on v2
    * `unstaked_earned0` - unstaked token0 fees earned
    * `unstaked_earned1` - unstaked token1 fees earned
    * `emissions_earned` - emissions earned from staked position
    * `tick_lower` - lower tick of position on v3, 0 on v2
    * `tick_upper` - upper tick of position on v3, 0 on v2
    * `alm` - true if position is deposited into ALM on v3, false on v2

---

The available methods are:
 * `all(_limit: uint256, _offset: uint256, _account: address) -> Lp[]` -
   returns a paginated list of `Lp` structs.
 * `byIndex(_index: uint256, _account: address) -> Lp` - returns the
   `Lp` data for a specific index of a pool.

---

For the pool epoch data we return, starting with most recent epoch, a struct of
type `LpEpoch` with the following values:

 * `ts` - the start of the epoch/week timestamp
 * `lp` - the pool address
 * `votes` - the amount of the votes for that epoch/week
 * `emissions` - emissions per second for that epoch/week
 * `bribes` - a list of bribes data, it is a struct of type `LpEpochBribe` with
   the following values:
    * `token` - bribe token address
    * `amount` - bribe amount
 * `fees` - a list of fees data, it is a struct of type `LpEpochBribe`,
   just like the `bribes` list

To fetch a list of epochs for a specific pool, this method is available:

 * `epochsByAddress(_limit: uint256, _offset: uint256, _address: address) -> LpEpoch[]`

To fetch a list of latest epochs data for a every pool, this method is available:

 * `epochsLatest(_limit: uint256, _offset: uint256) -> LpEpoch[]`

---

The pools token list (compiled from all the pools `token0`/`token1`) uses the type
`Token` with the following values:

 * `token_address` - the token address
 * `symbol` - the token symbol
 * `decimals` - the token decimals
 * `account_balance` - the provided account/wallet balance
 * `listed` - indicates if the token was listed for gauge voting rewards

To fetch the token list this method is available:

 * `tokens(_limit: uint256, _offset: uint256, _account: address, _oracle: address, _oracle_connectors: address[]) -> Token[]`

---

For the rewards, we return a struct of type `Reward` with the following
values:

 * `venft_id` - the veNFT id it belongs to
 * `lp` - the pool address representing the source of the reward
 * `amount` - the amount of the tokens accrued
 * `token` - the reward token address
 * `fee` - the fee contract address (if the reward comes from fees)
 * `bribe` - the bribe contract address (if the reward comes from bribes)

To fetch a list of rewards for a specific veNFT, this method is available:

 * `rewards(_limit: uint256, _offset: uint256, _venft_id: uint256) -> Reward[]`
 * `rewardsByAddress(_venft_id: uint256, _pool: address) -> Reward[]`

### Vote-Escrow Locked NFT (veNFT) Data

`VeSugar.vy` is deployed at `0x37403dBd6f1b583ea244F7956fF9e37EF45c63eB`

It allows fetching on-chain veNFT data (including the rewards accrued).
The returned data/struct of type `VeNFT` values represent:

  * `id` - veNFT token ID
  * `account` - veNFT token account address
  * `decimals` - veNFT token decimals
  * `amount` - veNFT locked amount
  * `voting_amount` - veNFT voting power
  * `governance_amount` - veNFT voting power in governance
  * `rebase_amount` - veNFT accrued reabses amount
  * `expires_at` - veNFT lock expiration timestamp
  * `voted_at` - veNFT last vote timestamp
  * `votes` - veNFT list of pools with vote weights casted in the form of
    `LpVotes`
  * `token` - veNFT locked token address
  * `permanent` - veNFT permanent lock enabled flag
  * `delegate_id` - token ID of the veNFT being delegated to

The pool votes struct values represent:
  * `lp` - the pool address
  * `weight` - the vote weights of the vote for the pool

---

The available methods are:

 * `all(_limit: uint256, _offset: uint256) -> VeNFT[]` - returns a paginated
   list of `veNFT` structs.
 * `byAccount(_account: address) -> VeNFT[]` - returns a list of `VeNFT` structs
   for a specific account.
 * `byId(_id: uint256) -> VeNFT` - returns the `VeNFT` struct for a specific
   NFT id.

### Relay Data

`RelaySugar.vy` is deployed at `0x062185EEF2726EFc11880856CD356FA2Ac2B38Ff`

It allows fetching Relay autocompounder/autoconverter data.
The returned data/struct of type `Relay` values represent:

  * `venft_id` - token ID of the Relay veNFT
  * `decimals` - Relay veNFT token decimals
  * `amount` - Relay veNFT locked amount
  * `voting_amount` - Relay veNFT voting power
  * `used_voting_amount` - Relay veNFT voting power used for last vote
  * `voted_at` - Relay veNFT last vote timestamp
  * `votes` - Relay veNFT list of pools with vote weights casted in the form of
    `LpVotes`
  * `token` - token address the Relay is compounding into
  * `compounded` - amount of tokens compounded into in the recent epoch
  * `run_at` - timestamp of last compounding
  * `manager` - Relay manager
  * `relay` - Relay address
  * `inactive` - Relay active/inactive status
  * `name` - Relay name
  * `account_venfts` - List of veNFTs deposited into this Relay by the account in the form of `ManagedVenft`

The managed veNFT deposit struct values represent:
  * `id` - the token ID of the veNFT
  * `amount` - the weight of the veNFT
  * `earned` - earned emissions of the veNFT

---

The available methods are:

 * `all(_account: address) -> Relay[]` - returns a list of all `Relay` structs.

## Development

To setup the environment, build the Docker image first:
```sh
docker build ./ -t velodrome/sugar
```

Next start the container with existing environment variables:
```sh
docker run --env-file=env.example --rm -v $(pwd):/app -w /app -it velodrome/sugar sh
```
The environment has Brownie and Vyper already installed.

To run the tests inside the container, use:
```sh
brownie test --network=optimism-test
```

## Why the contracts are not verified?

Sugar is written in Vyper, and Optimistic Etherscan fails at times to
generate the same bytecode (probably because of the hardcoded `evm_version`).

## How to generate the constructor arguments for verification?

Consider using the web tool at https://abi.hashex.org to build the arguments
and provide the generated value as part of the Etherscan verification form.
