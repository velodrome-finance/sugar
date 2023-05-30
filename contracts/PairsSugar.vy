# @version >=0.3.6 <0.4.0

# @title Velodrome Finance Liquidity Pairs Sugar v2
# @author stas
# @notice Makes it nicer to work with the liquidity pairs.

# Structs

MAX_FACTORIES: constant(uint256) = 10
MAX_POOLS: constant(uint256) = 1000
MAX_TOKENS: constant(uint256) = 2000
MAX_EPOCHS: constant(uint256) = 200
MAX_REWARDS: constant(uint256) = 16
WEEK: constant(uint256) = 7 * 24 * 60 * 60

struct Token:
  token_address: address
  symbol: String[100]
  decimals: uint8
  account_balance: uint256
  listed: bool

struct Pair:
  factory: address
  pair_address: address
  symbol: String[100]
  decimals: uint8
  stable: bool
  total_supply: uint256

  token0: address
  reserve0: uint256
  claimable0: uint256

  token1: address
  reserve1: uint256
  claimable1: uint256

  gauge: address
  gauge_total_supply: uint256
  gauge_alive: bool

  fee: address
  bribe: address

  emissions: uint256
  emissions_token: address

  account_balance: uint256
  account_earned: uint256
  account_staked: uint256

struct PairEpochReward:
  token: address
  amount: uint256

struct PairEpoch:
  ts: uint256
  pair_address: address
  votes: uint256
  emissions: uint256
  bribes: DynArray[PairEpochReward, MAX_REWARDS]
  fees: DynArray[PairEpochReward, MAX_REWARDS]

# Our contracts / Interfaces

interface IERC20:
  def decimals() -> uint8: view
  def symbol() -> String[100]: view
  def balanceOf(_account: address) -> uint256: view

interface IFactoryRegistry:
  def fallbackPoolFactory() -> address: view
  def poolFactories() -> DynArray[address, MAX_FACTORIES]: view
  def poolFactoriesLength() -> uint256: view

interface IPoolFactory:
  def allPoolsLength() -> uint256: view
  def allPools(_index: uint256) -> address: view
  # Backwards compatibility with V1
  def allPairsLength() -> uint256: view
  def allPairs(_index: uint256) -> address: view

interface IPool:
  def token0() -> address: view
  def token1() -> address: view
  def reserve0() -> uint256: view
  def reserve1() -> uint256: view
  def claimable0(_account: address) -> uint256: view
  def claimable1(_account: address) -> uint256: view
  def totalSupply() -> uint256: view
  def symbol() -> String[100]: view
  def decimals() -> uint8: view
  def stable() -> bool: view
  def balanceOf(_account: address) -> uint256: view

interface IVoter:
  def gauges(_pair_addr: address) -> address: view
  def gaugeToBribe(_gauge_addr: address) -> address: view
  def gaugeToFees(_gauge_addr: address) -> address: view
  def isAlive(_gauge_addr: address) -> bool: view
  def isWhitelistedToken(_token_addr: address) -> bool: view

interface IVotingEscrow:
  def token() -> address: view

interface IGauge:
  def fees0() -> uint256: view
  def fees1() -> uint256: view
  def earned(_account: address) -> uint256: view
  def balanceOf(_account: address) -> uint256: view
  def totalSupply() -> uint256: view
  def rewardRate() -> uint256: view
  def rewardRateByEpoch(_ts: uint256) -> uint256: view
  def rewardToken() -> address: view

interface IReward:
  def getPriorSupplyIndex(_ts: uint256) -> uint256: view
  def supplyCheckpoints(_index: uint256) -> uint256[2]: view
  def tokenRewardsPerEpoch(_token: address, _epstart: uint256) -> uint256: view
  def rewardsListLength() -> uint256: view
  def rewards(_index: uint256) -> address: view

# Vars
registry: public(address)
voter: public(address)
owner: public(address)
v1_factory: public(address)

# Methods

@external
def __init__():
  """
  @dev Sets up our contract management address
  """
  self.owner = msg.sender

@external
def setup(_voter: address, _registry: address, _v1_factory: address):
  """
  @dev Sets up our external contract addresses
  """
  assert self.owner == msg.sender, 'Not allowed!'

  self.voter = _voter
  self.registry = _registry
  self.v1_factory = _v1_factory


@internal
@view
def _pools() -> DynArray[address[3], MAX_POOLS]:
  """
  @notice Returns a compiled list of pool and its factory and gauge
  @return Array of three addresses (factory, pool, gauge)
  """
  registry: IFactoryRegistry = IFactoryRegistry(self.registry)
  factories_count: uint256 = registry.poolFactoriesLength()
  factories: DynArray[address, MAX_FACTORIES] = registry.poolFactories()

  pools: DynArray[address[3], MAX_POOLS] = \
    empty(DynArray[address[3], MAX_POOLS])

  for index in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: IPoolFactory = IPoolFactory(factories[index])
    pools_count: uint256 = 0
    legacy: bool = factory.address == self.v1_factory

    if legacy:
      pools_count = factory.allPairsLength()
    else:
      pools_count = factory.allPoolsLength()

    for pindex in range(0, MAX_POOLS):
      if pindex >= pools_count:
        break

      pool_addr: address = empty(address)

      if legacy:
        pool_addr = factory.allPairs(pindex)
      else:
        pool_addr = factory.allPools(pindex)

      gauge_addr: address = IVoter(self.voter).gauges(pool_addr)

      # Keep only legacy pools with gauges...
      if legacy == True and gauge_addr == empty(address):
        continue

      pools.append([factory.address, pool_addr, gauge_addr])

  return pools

@external
@view
def tokens(_limit: uint256, _offset: uint256, _account: address)\
  -> DynArray[Token, MAX_TOKENS]:
  """
  @notice Returns a collection of tokens data based on available pairs
  @param _limit The max amount of tokens to return
  @param _offset The amount of pairs to skip
  @param _account The account to check the balances
  @return Array for Token structs
  """
  pools: DynArray[address[3], MAX_POOLS] = self._pools()
  pools_count: uint256 = len(pools)
  col: DynArray[Token, MAX_TOKENS] = empty(DynArray[Token, MAX_TOKENS])
  seen: DynArray[address, MAX_TOKENS] = empty(DynArray[address, MAX_TOKENS])

  for index in range(_offset, _offset + MAX_TOKENS):
    if len(col) >= _limit or index >= pools_count:
      break

    pool_data: address[3] = pools[index]

    pool: IPool = IPool(pool_data[1])
    token0: address = pool.token0()
    token1: address = pool.token1()

    if token0 not in seen:
      col.append(self._token(token0, _account))
      seen.append(token0)

    if token1 not in seen:
      col.append(self._token(token1, _account))
      seen.append(token1)

  return col

@internal
@view
def _token(_address: address, _account: address) -> Token:
  voter: IVoter = IVoter(self.voter)
  token: IERC20 = IERC20(_address)
  bal: uint256 = empty(uint256)

  if _account != empty(address):
    bal = token.balanceOf(_account)

  return Token({
    token_address: _address,
    symbol: token.symbol(),
    decimals: token.decimals(),
    account_balance: bal,
    listed: voter.isWhitelistedToken(_address)
  })

@external
@view
def all(_limit: uint256, _offset: uint256, _account: address) \
    -> DynArray[Pair, MAX_POOLS]:
  """
  @notice Returns a collection of pair data
  @param _limit The max amount of pairs to return
  @param _offset The amount of pairs to skip
  @param _account The account to check the staked and earned balances
  @return Array for Pair structs
  """
  col: DynArray[Pair, MAX_POOLS] = empty(DynArray[Pair, MAX_POOLS])
  pools: DynArray[address[3], MAX_POOLS] = self._pools()
  pools_count: uint256 = len(pools)

  for index in range(_offset, _offset + MAX_POOLS):
    if len(col) == _limit or index >= pools_count:
      break

    col.append(self._byData(pools[index], _account))

  return col

@external
@view
def byIndex(_index: uint256, _account: address) -> Pair:
  """
  @notice Returns pair data at a specific stored index
  @param _index The index to lookup
  @param _account The account to check the staked and earned balances
  @return Pair struct
  """
  pools: DynArray[address[3], MAX_POOLS] = self._pools()

  return self._byData(pools[_index], _account)

@internal
@view
def _byData(_data: address[3], _account: address) -> Pair:
  """
  @notice Returns pair data based on the factory, pair and gauge addresses
  @param _address The addresses to lookup
  @param _account The user account
  @return Pair struct
  """
  voter: IVoter = IVoter(self.voter)
  pool: IPool = IPool(_data[1])
  gauge: IGauge = IGauge(_data[2])

  earned: uint256 = 0
  acc_staked: uint256 = 0
  gauge_total_supply: uint256 = 0
  emissions: uint256 = 0
  emissions_token: address = empty(address)

  if gauge.address != empty(address):
    acc_staked = gauge.balanceOf(_account)
    earned = gauge.earned(_account)
    gauge_total_supply = gauge.totalSupply()
    emissions = gauge.rewardRate()
    emissions_token = gauge.rewardToken()

  return Pair({
    factory: _data[0],
    pair_address: _data[1],
    symbol: pool.symbol(),
    decimals: pool.decimals(),
    stable: pool.stable(),
    total_supply: pool.totalSupply(),

    token0: pool.token0(),
    reserve0: pool.reserve0(),
    claimable0: pool.claimable0(_account),

    token1: pool.token1(),
    reserve1: pool.reserve1(),
    claimable1: pool.claimable1(_account),

    gauge: gauge.address,
    gauge_total_supply: gauge_total_supply,
    gauge_alive: voter.isAlive(gauge.address),

    fee: voter.gaugeToFees(gauge.address),
    bribe: voter.gaugeToBribe(gauge.address),

    emissions: emissions,
    emissions_token: emissions_token,

    account_balance: pool.balanceOf(_account),
    account_earned: earned,
    account_staked: acc_staked
  })

@external
@view
def epochsLatest(_limit: uint256, _offset: uint256) \
    -> DynArray[PairEpoch, MAX_POOLS]:
  """
  @notice Returns all pairs latest epoch data (up to 200 items)
  @param _limit The max amount of pairs to check for epochs
  @param _offset The amount of pairs to skip
  @return Array for PairEpoch structs
  """
  voter: IVoter = IVoter(self.voter)
  pools: DynArray[address[3], MAX_POOLS] = self._pools()
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[PairEpoch, MAX_POOLS] = empty(DynArray[PairEpoch, MAX_POOLS])

  for index in range(_offset, _offset + MAX_POOLS):
    if counted == _limit or index >= pools_count:
      break

    pool_data: address[3] = pools[index]

    if voter.isAlive(pool_data[2]) == False:
      continue

    col.append(self._epochLatestByAddress(pool_data[1], pool_data[2]))

    counted += 1

  return col

@external
@view
def epochsByAddress(_limit: uint256, _offset: uint256, _address: address) \
    -> DynArray[PairEpoch, MAX_EPOCHS]:
  """
  @notice Returns all pair epoch data based on the address
  @param _limit The max amount of epochs to return
  @param _offset The number of epochs to skip
  @param _address The address to lookup
  @return Array for PairEpoch structs
  """
  return self._epochsByAddress(_limit, _offset, _address)

@internal
@view
def _epochLatestByAddress(_address: address, _gauge: address) -> PairEpoch:
  """
  @notice Returns latest pair epoch data based on the address
  @param _address The pair address
  @param _gauge The pair gauge
  @return A PairEpoch struct
  """
  voter: IVoter = IVoter(self.voter)
  gauge: IGauge = IGauge(_gauge)
  bribe: IReward = IReward(voter.gaugeToBribe(gauge.address))

  epoch_start_ts: uint256 = block.timestamp / WEEK * WEEK
  epoch_end_ts: uint256 = epoch_start_ts + WEEK - 1

  bribe_supply_cp: uint256[2] = bribe.supplyCheckpoints(
    bribe.getPriorSupplyIndex(epoch_end_ts)
  )

  return PairEpoch({
    ts: epoch_start_ts,
    pair_address: _address,
    votes: bribe_supply_cp[1],
    emissions: gauge.rewardRateByEpoch(epoch_start_ts),
    bribes: self._epochRewards(epoch_start_ts, bribe.address),
    fees: self._epochRewards(epoch_start_ts, voter.gaugeToFees(gauge.address))
  })

@internal
@view
def _epochsByAddress(_limit: uint256, _offset: uint256, _address: address) \
    -> DynArray[PairEpoch, MAX_EPOCHS]:
  """
  @notice Returns all pair epoch data based on the address
  @param _limit The max amount of epochs to return
  @param _offset The number of epochs to skip
  @param _address The address to lookup
  @return Array for PairEpoch structs
  """
  assert _address != empty(address), 'Invalid address!'

  epochs: DynArray[PairEpoch, MAX_EPOCHS] = \
    empty(DynArray[PairEpoch, MAX_EPOCHS])

  voter: IVoter = IVoter(self.voter)
  gauge: IGauge = IGauge(voter.gauges(_address))

  if voter.isAlive(gauge.address) == False:
    return epochs

  bribe: IReward = IReward(voter.gaugeToBribe(gauge.address))

  curr_epoch_start_ts: uint256 = block.timestamp / WEEK * WEEK

  for weeks in range(_offset, _offset + MAX_EPOCHS):
    epoch_start_ts: uint256 = curr_epoch_start_ts - (weeks * WEEK)
    epoch_end_ts: uint256 = epoch_start_ts + WEEK - 1

    if len(epochs) == _limit or weeks >= MAX_EPOCHS:
      break

    bribe_supply_index: uint256 = bribe.getPriorSupplyIndex(epoch_end_ts)
    bribe_supply_cp: uint256[2] = bribe.supplyCheckpoints(bribe_supply_index)

    epochs.append(PairEpoch({
      ts: epoch_start_ts,
      pair_address: _address,
      votes: bribe_supply_cp[1],
      emissions: gauge.rewardRateByEpoch(epoch_start_ts),
      bribes: self._epochRewards(epoch_start_ts, bribe.address),
      fees: self._epochRewards(
        epoch_start_ts, voter.gaugeToFees(gauge.address)
      )
    }))

    # If we reach the last supply index...
    if bribe_supply_index == 0:
      break

  return epochs

@internal
@view
def _epochRewards(_ts: uint256, _reward: address) \
    -> DynArray[PairEpochReward, MAX_REWARDS]:
  """
  @notice Returns pair rewards
  @param _ts The pair epoch start timestamp
  @param _bribe The reward address
  @return An array of `PairEpochReward` structs
  """
  rewards: DynArray[PairEpochReward, MAX_REWARDS] = \
    empty(DynArray[PairEpochReward, MAX_REWARDS])

  if _reward == empty(address):
    return rewards

  reward: IReward = IReward(_reward)
  rewards_len: uint256 = reward.rewardsListLength()

  # Bribes have a 16 max rewards limit anyway...
  for rindex in range(MAX_REWARDS):
    if rindex >= rewards_len:
      break

    reward_token: address = reward.rewards(rindex)
    reward_amount: uint256 = reward.tokenRewardsPerEpoch(reward_token, _ts)

    if reward_amount == 0:
      continue

    rewards.append(PairEpochReward({
      token: reward_token,
      amount: reward_amount
    }))

  return rewards
