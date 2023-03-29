# Velodrome Sugar 🍭

Sugar comes with contracts to help working with Velodrome Finance data!

## How come?!

The idea is pretty simple, instead of relying on our API for a structured
data set of liquidity pairs data, these contracts can be called in an
efficient way to directly fetch the same data off-chain.

What normally would require:
  1. fetching the number of liquidity pairs
  2. querying every pair address at it's index
  3. querying pair tokens data
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

### Liquidity Pairs Data

`PairsSugar.vy` is deployed at `0x999abd60d58797D75CB7F1eF16619842e37A2954`

It allows fetching on-chain pairs data.
The returned data/struct of type `Pair` values represent:

 * `pair_address` - pair contract address
 * `symbol` - pair symbol
 * `decimals` - pair decimals
 * `stable` - pair pool type (`stable = false`, means it's a variable type of pool)
 * `total_supply` - pair tokens supply
 * `token0` - pair 1st token address
 * `reserve0` - pair 1st token reserves (nr. of tokens in the contract)
 * `claimable0` - claimable 1st token from fees (for unstaked positions)
 * `token1` - pair 2nd token address
 * `reserve1` - pair 2nd token reserves (nr. of tokens in the contract)
 * `claimable1` - claimable 2nd token from fees (for unstaked positions)
 * `gauge` - pair gauge address
 * `gauge_total_supply` - pair staked tokens (less/eq than/to pair total supply)
 * `gauge_alive` - indicates if the gauge is still active
 * `fee` - pair fees contract address
 * `bribe` - pair bribes contract address
 * `wrapped_bribe` - pair wrapped bribe contract address
 * `emissions` - pair emissions (per second)
 * `emissions_token` - pair emissions token address
 * `account_balance` - account LP tokens balance
 * `account_earned` - account earned emissions for this pair
 * `account_staked` - account pair staked in gauge balance

---

The available methods are:
 * `all(_limit: uint256, _offset: uint256, _account: address) -> Pair[]` -
   returns a paginated list of `Pair` structs.
 * `byIndex(_index: uint256, _account: address) -> Pair` - returns the
   `Pair` data for a specific index of a pair.
 * `byAddress(_address: address, _account: address) -> Pair` - returns the
   `Pair` data for a specific pair address.

---

For the pair epoch data we return, starting with most recent epoch, a struct of
type `PairEpoch` with the following values:

 * `ts` - the start of the epoch/week timestamp
 * `pair_address` - the pair address
 * `votes` - the amount of the votes for that epoch/week
 * `emissions` - emissions per second for that epoch/week
 * `bribes` - a list of bribes data, it is a struct of type `PairEpochBribe` with
   the following values:
    * `token` - bribe token address
    * `amount` - bribe amount
 * `fees` - a list of fees data, it is a struct of type `PairEpochBribe`,
   just like the `bribes` list

To fetch a list of epochs for a specific pair, this method is available:

 * `epochsByAddress(_limit: uint256, _offset: uint256, _address: address) -> PairEpoch[]`

To fetch a list of latest epochs data for a every pair, this method is available:

 * `epochsLatest(_limit: uint256, _offset: uint256) -> PairEpoch[]`

---

The pairs token list (compiled from all the pools `token0`/`token1`) uses the type
`Token` with the following values:

 * `token_address` - the token address
 * `symbol` - the token symbol
 * `decimals` - the token decimals
 * `account_balance` - the provided account/wallet balance
 * `listed` - indicates if the token was listed for gauge voting rewards

To fetch the token list this method is available:

 * `tokens(_limit: uint256, _offset: uint256, _account: address, _oracle: address, _oracle_connectors: address[]) -> Token[]`

### Vote-Escrow Locked NFT (veNFT) Data

`VeSugar.vy` is deployed at `0x925A0d9d2000c4919e7BF0a0d5F2995a2bfE8542`

It allows fetching on-chain veNFT data (including the rewards accrued).
The returned data/struct of type `VeNFT` values represent:

  * `id` - veNFT token ID
  * `account` - veNFT token account address
  * `decimals` - veNFT token decimals
  * `amount` - veNFT locked amount
  * `voting_amount` - veNFT voting power
  * `rebase_amount` - veNFT accrued reabses amount
  * `expires_at` - veNFT lock expiration timestamp
  * `voted_at` - veNFT last vote timestamp
  * `votes` - veNFT list of pairs with vote weights casted in the form of
    `PairVotes`
  * `token` - veNFT locked token address
  * `attachments` - veNFT nr. of attachments (aka gauges it is attached to)

The pair votes struct values represent:
  * `pair` - the pair address
  * `weight` - the vote weights of the vote for the pair

---

The available methods are:

 * `all(_limit: uint256, _offset: uint256) -> VeNFT[]` - returns a paginated
   list of `veNFT` structs.
 * `byAccount(_account: address) -> VeNFT[]` - returns a list of `VeNFT` structs
   for a specific account.
 * `byId(_id: uint256) -> VeNFT` - returns the `VeNFT` struct for a specific
   NFT id.

---

For the veNFT rewards, we return a struct of type `Reward` with the following
values:

 * `venft_id` - the veNFT id it belongs to
 * `pair` - the pair address representing the source of the reward
 * `amount` - the amount of the tokens accrued
 * `token` - the reward token address
 * `fee` - the fee contract address (if the reward comes from fees)
 * `bribe` - the bribe contract address (if the reward comes from bribes)

To fetch a list of rewards for a specific veNFT, this method is available:

 * `rewards(_limit: uint256, _offset: uint256, _venft_id: uint256) -> Reward[]`
 * `rewardsByPair(_venft_id: uint256, _pair: address) -> Reward[]`

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
