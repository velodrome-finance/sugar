# SPDX-License-Identifier: BUSL-1.1
# @version >=0.3.6 <0.4.0

# @title Velodrome Finance LP Sugar v2
# @author stas
# @notice Makes it nicer to work with the liquidity pools.

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

struct SwapLp:
  lp: address
  stable: bool
  token0: address
  token1: address
  factory: address

struct Lp:
  lp: address
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
  factory: address

  emissions: uint256
  emissions_token: address

  account_balance: uint256
  account_earned: uint256
  account_staked: uint256

struct LpEpochReward:
  token: address
  amount: uint256

struct LpEpoch:
  ts: uint256
  lp: address
  votes: uint256
  emissions: uint256
  bribes: DynArray[LpEpochReward, MAX_REWARDS]
  fees: DynArray[LpEpochReward, MAX_REWARDS]

struct Reward:
  venft_id: uint256
  lp: address
  amount: uint256
  token: address
  fee: address
  bribe: address


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
  def gauges(_pool_addr: address) -> address: view
  def gaugeToBribe(_gauge_addr: address) -> address: view
  def gaugeToFees(_gauge_addr: address) -> address: view
  def isAlive(_gauge_addr: address) -> bool: view
  def isWhitelistedToken(_token_addr: address) -> bool: view
  def v1Factory() -> address: view

interface IGaugeV1:
  def earned(_token:address, _account: address) -> uint256: view
  def rewardRate(_token:address) -> uint256: view

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
  def earned(_token: address, _venft_id: uint256) -> uint256: view

# Vars
registry: public(IFactoryRegistry)
voter: public(IVoter)
convertor: public(address)
v1_voter: public(IVoter)
v1_factory: public(address)
v1_token: public(address)

# Methods

@external
def __init__(
    _voter: address,
    _registry: address,
    _v1_voter: address,
    _convertor: address
  ):
  """
  @dev Sets up our external contract addresses
  """
  self.voter = IVoter(_voter)
  self.v1_voter = IVoter(_v1_voter)
  self.registry = IFactoryRegistry(_registry)
  self.convertor = _convertor

  self.v1_factory = self.voter.v1Factory()
  self.v1_token = IPool(self.convertor).token0()

@internal
@view
def _pools(with_convertor: bool) -> DynArray[address[3], MAX_POOLS]:
  """
  @notice Returns a compiled list of pool and its factory and gauge (sans v1)
  @return Array of three addresses (factory, pool, gauge)
  """
  factories_count: uint256 = self.registry.poolFactoriesLength()
  factories: DynArray[address, MAX_FACTORIES] = self.registry.poolFactories()

  pools: DynArray[address[3], MAX_POOLS] = \
    empty(DynArray[address[3], MAX_POOLS])

  for index in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: IPoolFactory = IPoolFactory(factories[index])

    if factory.address == self.v1_factory:
      continue

    pools_count: uint256 = factory.allPoolsLength()

    for pindex in range(0, MAX_POOLS):
      if pindex >= pools_count:
        break

      pool_addr: address = factory.allPools(pindex)

      if with_convertor == False and pool_addr == self.convertor:
        continue

      gauge_addr: address = self.voter.gauges(pool_addr)

      pools.append([factory.address, pool_addr, gauge_addr])

  return pools

@external
@view
def toMigrate(_account: address) -> DynArray[Lp, MAX_POOLS]:
  """
  @notice Returns a collection of pool data to be migrated (from v1)
  @return `LP` structs
  """
  pools: DynArray[Lp, MAX_POOLS] = empty(DynArray[Lp, MAX_POOLS])

  if _account ==  empty(address):
    return pools

  factory: IPoolFactory = IPoolFactory(self.v1_factory)
  pools_count: uint256 = factory.allPairsLength()

  for pindex in range(0, MAX_POOLS):
    if pindex >= pools_count:
      break

    pool: IPool = IPool(factory.allPairs(pindex))
    gauge: IGauge = IGauge(self.v1_voter.gauges(pool.address))

    account_balance: uint256 = pool.balanceOf(_account)
    account_staked: uint256 = 0
    gauge_total_supply: uint256 = 0
    earned: uint256 = 0
    emissions: uint256 = 0

    if gauge.address != empty(address):
      account_staked = gauge.balanceOf(_account)

    if account_balance == 0 and account_staked == 0:
      continue

    if account_staked > 0:
      earned = IGaugeV1(gauge.address).earned(self.v1_token, _account)
      gauge_total_supply = gauge.totalSupply()
      emissions = IGaugeV1(gauge.address).rewardRate(self.v1_token)

    pools.append(Lp({
      lp: pool.address,
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
      # Save gas...
      gauge_alive: False,

      fee: empty(address),
      bribe: empty(address),
      factory: self.v1_factory,

      emissions: emissions,
      emissions_token: self.v1_token,

      account_balance: pool.balanceOf(_account),
      account_earned: earned,
      account_staked: account_staked
    }))

  return pools

@external
@view
def forSwaps() -> DynArray[SwapLp, MAX_POOLS]:
  """
  @notice Returns a compiled list of pools for swaps from all pool factories
  @return `SwapLp` structs
  """
  factories_count: uint256 = self.registry.poolFactoriesLength()
  factories: DynArray[address, MAX_FACTORIES] = self.registry.poolFactories()

  pools: DynArray[SwapLp, MAX_POOLS] = empty(DynArray[SwapLp, MAX_POOLS])

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

      pool: IPool = IPool(pool_addr)

      reserve0: uint256 = pool.reserve0()
      reserve1: uint256 = pool.reserve1()

      if (reserve0 > 0 and reserve1 > 0) or pool_addr == self.convertor:
        pools.append(SwapLp({
          lp: pool_addr,
          stable: pool.stable(),
          token0: pool.token0(),
          token1: pool.token1(),
          factory: factory.address
        }))

  return pools

@external
@view
def tokens(_limit: uint256, _offset: uint256, _account: address)\
  -> DynArray[Token, MAX_TOKENS]:
  """
  @notice Returns a collection of tokens data based on available pools
  @param _limit The max amount of tokens to return
  @param _offset The amount of pools to skip
  @param _account The account to check the balances
  @return Array for Token structs
  """
  pools: DynArray[address[3], MAX_POOLS] = self._pools(True)
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
  token: IERC20 = IERC20(_address)
  bal: uint256 = empty(uint256)

  if _account != empty(address):
    bal = token.balanceOf(_account)

  return Token({
    token_address: _address,
    symbol: token.symbol(),
    decimals: token.decimals(),
    account_balance: bal,
    listed: self.voter.isWhitelistedToken(_address)
  })

@external
@view
def all(_limit: uint256, _offset: uint256, _account: address) \
    -> DynArray[Lp, MAX_POOLS]:
  """
  @notice Returns a collection of pool data
  @param _limit The max amount of pools to return
  @param _offset The amount of pools to skip
  @param _account The account to check the staked and earned balances
  @return Array for Lp structs
  """
  col: DynArray[Lp, MAX_POOLS] = empty(DynArray[Lp, MAX_POOLS])
  pools: DynArray[address[3], MAX_POOLS] = self._pools(False)
  pools_count: uint256 = len(pools)

  for index in range(_offset, _offset + MAX_POOLS):
    if len(col) == _limit or index >= pools_count:
      break

    col.append(self._byData(pools[index], _account))

  return col

@external
@view
def byIndex(_index: uint256, _account: address) -> Lp:
  """
  @notice Returns pool data at a specific stored index
  @param _index The index to lookup
  @param _account The account to check the staked and earned balances
  @return Lp struct
  """
  pools: DynArray[address[3], MAX_POOLS] = self._pools(False)

  return self._byData(pools[_index], _account)

@internal
@view
def _byData(_data: address[3], _account: address) -> Lp:
  """
  @notice Returns pool data based on the factory, pool and gauge addresses
  @param _address The addresses to lookup
  @param _account The user account
  @return Lp struct
  """
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

  return Lp({
    lp: _data[1],
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
    gauge_alive: self.voter.isAlive(gauge.address),

    fee: self.voter.gaugeToFees(gauge.address),
    bribe: self.voter.gaugeToBribe(gauge.address),
    factory: _data[0],

    emissions: emissions,
    emissions_token: emissions_token,

    account_balance: pool.balanceOf(_account),
    account_earned: earned,
    account_staked: acc_staked
  })

@external
@view
def epochsLatest(_limit: uint256, _offset: uint256) \
    -> DynArray[LpEpoch, MAX_POOLS]:
  """
  @notice Returns all pools latest epoch data (up to 200 items)
  @param _limit The max amount of pools to check for epochs
  @param _offset The amount of pools to skip
  @return Array for LpEpoch structs
  """
  pools: DynArray[address[3], MAX_POOLS] = self._pools(False)
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[LpEpoch, MAX_POOLS] = empty(DynArray[LpEpoch, MAX_POOLS])

  for index in range(_offset, _offset + MAX_POOLS):
    if counted == _limit or index >= pools_count:
      break

    pool_data: address[3] = pools[index]

    if self.voter.isAlive(pool_data[2]) == False:
      continue

    col.append(self._epochLatestByAddress(pool_data[1], pool_data[2]))

    counted += 1

  return col

@external
@view
def epochsByAddress(_limit: uint256, _offset: uint256, _address: address) \
    -> DynArray[LpEpoch, MAX_EPOCHS]:
  """
  @notice Returns all pool epoch data based on the address
  @param _limit The max amount of epochs to return
  @param _offset The number of epochs to skip
  @param _address The address to lookup
  @return Array for LpEpoch structs
  """
  return self._epochsByAddress(_limit, _offset, _address)

@internal
@view
def _epochLatestByAddress(_address: address, _gauge: address) -> LpEpoch:
  """
  @notice Returns latest pool epoch data based on the address
  @param _address The pool address
  @param _gauge The pool gauge
  @return A LpEpoch struct
  """
  gauge: IGauge = IGauge(_gauge)
  bribe: IReward = IReward(self.voter.gaugeToBribe(gauge.address))

  epoch_start_ts: uint256 = block.timestamp / WEEK * WEEK
  epoch_end_ts: uint256 = epoch_start_ts + WEEK - 1

  bribe_supply_cp: uint256[2] = bribe.supplyCheckpoints(
    bribe.getPriorSupplyIndex(epoch_end_ts)
  )

  return LpEpoch({
    ts: epoch_start_ts,
    lp: _address,
    votes: bribe_supply_cp[1],
    emissions: gauge.rewardRateByEpoch(epoch_start_ts),
    bribes: self._epochRewards(epoch_start_ts, bribe.address),
    fees: self._epochRewards(
      epoch_start_ts, self.voter.gaugeToFees(gauge.address)
    )
  })

@internal
@view
def _epochsByAddress(_limit: uint256, _offset: uint256, _address: address) \
    -> DynArray[LpEpoch, MAX_EPOCHS]:
  """
  @notice Returns all pool epoch data based on the address
  @param _limit The max amount of epochs to return
  @param _offset The number of epochs to skip
  @param _address The address to lookup
  @return Array for LpEpoch structs
  """
  assert _address != empty(address), 'Invalid address!'

  epochs: DynArray[LpEpoch, MAX_EPOCHS] = \
    empty(DynArray[LpEpoch, MAX_EPOCHS])

  gauge: IGauge = IGauge(self.voter.gauges(_address))

  if self.voter.isAlive(gauge.address) == False:
    return epochs

  bribe: IReward = IReward(self.voter.gaugeToBribe(gauge.address))

  curr_epoch_start_ts: uint256 = block.timestamp / WEEK * WEEK

  for weeks in range(_offset, _offset + MAX_EPOCHS):
    epoch_start_ts: uint256 = curr_epoch_start_ts - (weeks * WEEK)
    epoch_end_ts: uint256 = epoch_start_ts + WEEK - 1

    if len(epochs) == _limit or weeks >= MAX_EPOCHS:
      break

    bribe_supply_index: uint256 = bribe.getPriorSupplyIndex(epoch_end_ts)
    bribe_supply_cp: uint256[2] = bribe.supplyCheckpoints(bribe_supply_index)

    epochs.append(LpEpoch({
      ts: epoch_start_ts,
      lp: _address,
      votes: bribe_supply_cp[1],
      emissions: gauge.rewardRateByEpoch(epoch_start_ts),
      bribes: self._epochRewards(epoch_start_ts, bribe.address),
      fees: self._epochRewards(
        epoch_start_ts, self.voter.gaugeToFees(gauge.address)
      )
    }))

    # If we reach the last supply index...
    if bribe_supply_index == 0:
      break

  return epochs

@internal
@view
def _epochRewards(_ts: uint256, _reward: address) \
    -> DynArray[LpEpochReward, MAX_REWARDS]:
  """
  @notice Returns pool rewards
  @param _ts The pool epoch start timestamp
  @param _bribe The reward address
  @return An array of `LpEpochReward` structs
  """
  rewards: DynArray[LpEpochReward, MAX_REWARDS] = \
    empty(DynArray[LpEpochReward, MAX_REWARDS])

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

    rewards.append(LpEpochReward({
      token: reward_token,
      amount: reward_amount
    }))

  return rewards

@external
@view
def rewards(_limit: uint256, _offset: uint256, _venft_id: uint256) \
    -> DynArray[Reward, MAX_POOLS]:
  """
  @notice Returns a collection of veNFT rewards data
  @param _limit The max amount of pools to check for rewards
  @param _offset The amount of pools to skip checking for rewards
  @param _venft_id The veNFT ID to get rewards for
  @return Array for VeNFT Reward structs
  """
  pools: DynArray[address[3], MAX_POOLS] = self._pools(False)
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[Reward, MAX_POOLS] = empty(DynArray[Reward, MAX_POOLS])

  for pindex in range(_offset, _offset + MAX_POOLS):
    if counted == _limit or pindex >= pools_count:
      break

    pool_data: address[3] = pools[pindex]
    pcol: DynArray[Reward, MAX_POOLS] = \
      self._poolRewards(_venft_id, pool_data[1], pool_data[2])

    # Basically merge pool rewards to the rest of the rewards...
    for cindex in range(MAX_POOLS):
      if cindex >= len(pcol):
        break

      col.append(pcol[cindex])

    counted += 1

  return col

@external
@view
def rewardsByAddress(_venft_id: uint256, _pool: address) \
    -> DynArray[Reward, MAX_POOLS]:
  """
  @notice Returns a collection of veNFT rewards data for a specific pool
  @param _venft_id The veNFT ID to get rewards for
  @param _pool The pool address to get rewards for
  @return Array for VeNFT Reward structs
  """
  gauge_addr: address = self.voter.gauges(_pool)

  return self._poolRewards(_venft_id, _pool, gauge_addr)

@internal
@view
def _poolRewards(_venft_id: uint256, _pool: address, _gauge: address) \
    -> DynArray[Reward, MAX_POOLS]:
  """
  @notice Returns a collection with veNFT pool rewards
  @param _venft_id The veNFT ID to get rewards for
  @param _pool The pool address
  @param _gauge The pool gauge address
  @param _col The array of `Reward` sturcts to update
  """
  pool: IPool = IPool(_pool)

  col: DynArray[Reward, MAX_POOLS] = empty(DynArray[Reward, MAX_POOLS])

  if _pool == empty(address) or _gauge == empty(address):
    return col

  fee: IReward = IReward(self.voter.gaugeToFees(_gauge))
  bribe: IReward = IReward(self.voter.gaugeToBribe(_gauge))

  token0: address = pool.token0()
  token1: address = pool.token1()

  fee0_amount: uint256 = fee.earned(token0, _venft_id)
  fee1_amount: uint256 = fee.earned(token1, _venft_id)

  if fee0_amount > 0:
    col.append(
      Reward({
        venft_id: _venft_id,
        lp: pool.address,
        amount: fee0_amount,
        token: token0,
        fee: fee.address,
        bribe: empty(address)
      })
    )

  if fee1_amount > 0:
    col.append(
      Reward({
        venft_id: _venft_id,
        lp: pool.address,
        amount: fee1_amount,
        token: token1,
        fee: fee.address,
        bribe: empty(address)
      })
    )

  if bribe.address == empty(address):
    return col

  bribes_len: uint256 = bribe.rewardsListLength()

  # Bribes have a 16 max rewards limit anyway...
  for bindex in range(MAX_REWARDS):
    if bindex >= bribes_len:
      break

    bribe_token: address = bribe.rewards(bindex)
    bribe_amount: uint256 = bribe.earned(bribe_token, _venft_id)

    if bribe_amount == 0:
      continue

    col.append(
      Reward({
        venft_id: _venft_id,
        lp: pool.address,
        amount: bribe_amount,
        token: bribe_token,
        fee: empty(address),
        bribe: bribe.address
      })
    )

  return col
