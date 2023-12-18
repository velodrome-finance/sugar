# SPDX-License-Identifier: BUSL-1.1
# @version >=0.3.6 <0.4.0

# @title Velodrome Finance LP Sugar v3
# @author stas, ethzoomer
# @notice Makes it nicer to work with the liquidity pools.

# Structs

MAX_FACTORIES: constant(uint256) = 10
MAX_POOLS: constant(uint256) = 500
MAX_TOKENS: constant(uint256) = 2000
MAX_EPOCHS: constant(uint256) = 200
MAX_REWARDS: constant(uint256) = 16
MAX_POSITIONS: constant(uint256) = 10
WEEK: constant(uint256) = 7 * 24 * 60 * 60

# Slot0 from V3Pool.sol
struct Slot:
  sqrt_price: uint160
  tick: int24
  observation_index: uint16
  cardinality: uint16
  cardinality_next: uint16
  unlocked: bool

# GaugeFees from V3Pool.sol
struct GaugeFees:
  token0: uint128
  token1: uint128

# Position from NonfungiblePositionManager.sol (NFT)
struct PositionData:
  nonce: uint96
  operator: address
  pool_id: uint80
  tick_lower: int24
  tick_upper: int24
  liquidity: uint128
  fee_growth0: uint256
  fee_growth1: uint256
  unstaked_earned0: uint128
  unstaked_earned1: uint128

struct Position:
  id: uint256 # NFT ID on v3, 0 on v2
  manager: address # NFT Position Manager on v3, router on v2
  liquidity: uint256 # Liquidity value on v3, amt of LP tokens on v2
  staked: uint256 # 0/1 for staked state on v3, amt of staked LP tokens on v2
  unstaked_earned0: uint256 # unstaked token0 fees earned on both v2 and v3
  unstaked_earned1: uint256 # unstaked token1 fees earned on both v2 and v3
  emissions_earned: uint256 # staked liq emissions earned on both v2 and v3
  tick_lower: int24 # Position lower tick on v3, 0 on v2
  tick_upper: int24 # Position upper tick on v3, 0 on v2
  alm: bool # True if Position is deposited into ALM on v3, False on v2

struct Token:
  token_address: address
  symbol: String[100]
  decimals: uint8
  account_balance: uint256
  listed: bool

struct SwapLp:
  lp: address
  type: int24 # tick spacing on v3, 0/-1 for stable/volatile on v2
  token0: address
  token1: address
  factory: address

struct Lp:
  lp: address
  symbol: String[100]
  decimals: uint8
  total_supply: uint256

  nft: address 
  type: int24 # tick spacing on v3, 0/-1 for stable/volatile on v2
  tick: int24 # current tick on v3, 0 on v2
  price: uint160 # current price on v3, 0 on v2

  token0: address
  reserve0: uint256

  token1: address
  reserve1: uint256

  gauge: address
  gauge_total_supply: uint256
  gauge_alive: bool

  fee: address
  bribe: address
  factory: address

  emissions: uint256
  emissions_token: address

  pool_fee: uint256 # staked fee % on v3, fee % on v2
  unstaked_fee: uint256 # unstaked fee % on v3, 0 on v2
  token0_fees: uint256
  token1_fees: uint256

  alm_vault: address # ALM vault address on v3, empty address on v2
  alm_reserve0: uint256 # ALM token0 reserves on v3, 0 on v2
  alm_reserve1: uint256 # ALM token1 reserves on v3, 0 on v2

  positions: DynArray[Position, MAX_POSITIONS]

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
  def getFee(_pool_addr: address, _stable: bool) -> uint256: view
  def getPool(_token0: address, _token1: address, _fee: uint24) -> address: view

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
  def poolFees() -> address: view
  def gauge() -> address: view # fetches gauge from v3 pool
  def nft() -> address: view # fetches nft address from v3 pool
  def tickSpacing() -> int24: view # v3 tick spacing
  def slot0() -> Slot: view # v3 slot data
  def gaugeFees() -> GaugeFees: view # v3 gauge fees amounts
  def fee() -> uint24: view # v3 fee level
  def unstakedFee() -> uint24: view # v3 unstaked fee level

interface IVoter:
  def gauges(_pool_addr: address) -> address: view
  def gaugeToBribe(_gauge_addr: address) -> address: view
  def gaugeToFees(_gauge_addr: address) -> address: view
  def isAlive(_gauge_addr: address) -> bool: view
  def isWhitelistedToken(_token_addr: address) -> bool: view
  def v1Factory() -> address: view

interface IGauge:
  def fees0() -> uint256: view
  def fees1() -> uint256: view
  def earned(_account: address) -> uint256: view
  def balanceOf(_account: address) -> uint256: view
  def totalSupply() -> uint256: view
  def rewardRate() -> uint256: view
  def rewardRateByEpoch(_ts: uint256) -> uint256: view
  def rewardToken() -> address: view

interface ICLGauge:
  def earned(_account: address, _position_id: uint256) -> uint256: view
  def rewardRate() -> uint256: view
  def rewardRateByEpoch(_ts: uint256) -> uint256: view
  def rewardToken() -> address: view
  def feesVotingReward() -> address: view
  def stakedContains(_account: address, _position_id: uint256) -> bool: view

interface INFTPositionManager:
  def positions(_position_id: uint256) -> PositionData: view
  def tokenOfOwnerByIndex(_account: address, _index: uint256) -> uint256: view

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
router: public(address)
v1_factory: public(address)
alm_registry: public(address) # todo: add ALM interface when ALM contracts are ready

# Methods

@external
def __init__(_voter: address, _registry: address, _convertor: address, _router: address, _alm_registry: address):
  """
  @dev Sets up our external contract addresses
  """
  self.voter = IVoter(_voter)
  self.registry = IFactoryRegistry(_registry)
  self.convertor = _convertor
  self.router = _router
  self.v1_factory = self.voter.v1Factory()
  self.alm_registry = _alm_registry

@internal
@view
def _pools() -> DynArray[address[3], MAX_POOLS]:
  """
  @notice Returns a compiled list of pool and its factory and gauge
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

      if pool_addr == self.convertor:
        continue

      gauge_addr: address = self.voter.gauges(pool_addr)

      pools.append([factory.address, pool_addr, gauge_addr])

  return pools

@external
@view
def forSwaps(_limit: uint256, _offset: uint256) -> DynArray[SwapLp, MAX_POOLS]:
  """
  @notice Returns a compiled list of pools for swaps from pool factories (sans v1)
  @param _limit The max amount of tokens to return
  @param _offset The amount of pools to skip
  @return `SwapLp` structs
  """
  factories_count: uint256 = self.registry.poolFactoriesLength()
  factories: DynArray[address, MAX_FACTORIES] = self.registry.poolFactories()

  pools: DynArray[SwapLp, MAX_POOLS] = empty(DynArray[SwapLp, MAX_POOLS])

  for index in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    if factories[index] == self.v1_factory:
      continue

    factory: IPoolFactory = IPoolFactory(factories[index])

    pools_count: uint256 = factory.allPoolsLength()

    for pindex in range(_offset, _offset + MAX_POOLS):
      if len(pools) >= _limit or pindex >= pools_count:
        break

      pool_addr: address = factory.allPools(pindex)
      pool: IPool = IPool(pool_addr)
      type: int24 = -1
      token0: address = pool.token0()
      token1: address = pool.token1()
      reserve0: uint256 = 0

      is_cl_pool: bool = False
      is_stable: bool = factory.getPool(token0, token1, 0) == pool_addr

      if not is_stable and factory.getPool(token0, token1, 1) != pool_addr:
        is_cl_pool = True

      if is_cl_pool:
        type = pool.tickSpacing()
        reserve0 = IERC20(token0).balanceOf(pool_addr)

      else:
        if is_stable:
          type = 0
        reserve0 = pool.reserve0()

      if reserve0 > 0:
        pools.append(SwapLp({
          lp: pool_addr,
          type: type,
          token0: token0,
          token1: token1,
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
  pools: DynArray[address[3], MAX_POOLS] = self._pools()
  pools_count: uint256 = len(pools)

  for index in range(_offset, _offset + MAX_POOLS):
    if len(col) == _limit or index >= pools_count:
      break

    pool: IPool = IPool(pools[index][1])
    factory: IPoolFactory = IPoolFactory(pools[index][0])
    token0: address = pool.token0()
    token1: address = pool.token1()

    is_cl_pool: bool = False
    is_stable: bool = factory.getPool(token0, token1, 0) == pool.address

    if not is_stable and factory.getPool(token0, token1, 1) != pool.address:
      is_cl_pool = True

    if is_cl_pool:
      col.append(self._byDataCL(pools[index], token0, token1, _account))
    else:
      col.append(self._byData(pools[index], token0, token1, _account))

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
  pools: DynArray[address[3], MAX_POOLS] = self._pools()

  pool: IPool = IPool(pools[_index][1])
  factory: IPoolFactory = IPoolFactory(pools[_index][0])
  token0: address = pool.token0()
  token1: address = pool.token1()

  is_cl_pool: bool = False
  is_stable: bool = factory.getPool(token0, token1, 0) == pool.address

  if not is_stable and factory.getPool(token0, token1, 1) != pool.address:
    is_cl_pool = True

  if is_cl_pool:
    return self._byDataCL(pools[_index], token0, token1, _account)
  return self._byData(pools[_index], token0, token1, _account)

@internal
@view
def _byData(_data: address[3], _token0: address, _token1: address, _account: address) -> Lp:
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
  is_stable: bool = pool.stable()
  pool_fee: uint256 = IPoolFactory(_data[0]).getFee(_data[1], is_stable)
  pool_fees: address = pool.poolFees()
  token0: IERC20 = IERC20(_token0)
  token1: IERC20 = IERC20(_token1)
  gauge_alive: bool = self.voter.isAlive(gauge.address)

  type: int24 = -1
  if is_stable:
    type = 0

  if gauge.address != empty(address):
    acc_staked = gauge.balanceOf(_account)
    earned = gauge.earned(_account)
    gauge_total_supply = gauge.totalSupply()
    emissions_token = gauge.rewardToken()

  if gauge_alive:
    emissions = gauge.rewardRate()

  positions: DynArray[Position, MAX_POSITIONS] = empty(DynArray[Position, MAX_POSITIONS])

  positions.append(
    Position({
      id: 0,
      manager: self.router,
      liquidity: pool.balanceOf(_account),
      staked: acc_staked,
      unstaked_earned0: pool.claimable0(_account),
      unstaked_earned1: pool.claimable1(_account),
      emissions_earned: earned,
      tick_lower: 0,
      tick_upper: 0,
      alm: False
    })
  )

  return Lp({
    lp: _data[1],
    symbol: pool.symbol(),
    decimals: pool.decimals(),
    total_supply: pool.totalSupply(),

    nft: empty(address),
    type: type,
    tick: 0,
    price: 0,

    token0: token0.address,
    reserve0: pool.reserve0(),

    token1: token1.address,
    reserve1: pool.reserve1(),

    gauge: gauge.address,
    gauge_total_supply: gauge_total_supply,
    gauge_alive: gauge_alive,

    fee: self.voter.gaugeToFees(gauge.address),
    bribe: self.voter.gaugeToBribe(gauge.address),
    factory: _data[0],

    emissions: emissions,
    emissions_token: emissions_token,

    pool_fee: pool_fee,
    unstaked_fee: 0,
    token0_fees: token0.balanceOf(pool_fees),
    token1_fees: token1.balanceOf(pool_fees),

    alm_vault: empty(address),
    alm_reserve0: 0,
    alm_reserve1: 0,

    positions: positions
  })

@internal
@view
def _byDataCL(_data: address[3], _token0: address, _token1: address, _account: address) -> Lp:
  """
  @notice Returns CL pool data based on the factory, pool and gauge addresses
  @param _data The addresses to lookup
  @param _account The user account
  @return Lp struct
  """
  pool: IPool = IPool(_data[1])
  gauge: ICLGauge = ICLGauge(_data[2])
  nft: INFTPositionManager = INFTPositionManager(pool.nft())

  gauge_fees: GaugeFees = pool.gaugeFees()
  gauge_alive: bool = self.voter.isAlive(gauge.address)
  fee_voting_reward: address = empty(address)
  emissions: uint256 = 0
  emissions_token: address = empty(address)
  token0: IERC20 = IERC20(_token0)
  token1: IERC20 = IERC20(_token1)

  fee_voting_reward = gauge.feesVotingReward()
  emissions_token = gauge.rewardToken()

  if gauge_alive:
    emissions = gauge.rewardRate()

  slot: Slot = pool.slot0()
  price: uint160 = slot.sqrt_price

  positions: DynArray[Position, MAX_POSITIONS] = empty(DynArray[Position, MAX_POSITIONS])
  
  for index in range(0, MAX_POSITIONS):
    position_id: uint256 = nft.tokenOfOwnerByIndex(_account, index)

    if position_id == 0:
      break

    position_data: PositionData = nft.positions(position_id)

    emissions_earned: uint256 = 0
    staked: bool = False

    if gauge.address != empty(address):
      emissions_earned = gauge.earned(_account, position_id)
      staked = gauge.stakedContains(_account, position_id)

    positions.append(
      Position({
        id: position_id,
        manager: pool.nft(),
        liquidity: convert(position_data.liquidity, uint256),
        staked: convert(staked, uint256),
        unstaked_earned0: convert(position_data.unstaked_earned0, uint256),
        unstaked_earned1: convert(position_data.unstaked_earned1, uint256),
        emissions_earned: emissions_earned,
        tick_lower: position_data.tick_lower,
        tick_upper: position_data.tick_upper,
        alm: False # todo: populate real ALM data when ALM contracts are ready
      })
    )

  return Lp({
    lp: pool.address,
    symbol: "",
    decimals: 0,
    total_supply: 0,

    nft: nft.address,
    type: pool.tickSpacing(),
    tick: slot.tick,
    price: price,

    token0: token0.address,
    reserve0: token0.balanceOf(pool.address),

    token1: token1.address,
    reserve1: token1.balanceOf(pool.address),

    gauge: gauge.address,
    gauge_total_supply: 0,
    gauge_alive: gauge_alive,

    fee: fee_voting_reward,
    bribe: self.voter.gaugeToBribe(gauge.address),
    factory: _data[0],

    emissions: emissions,
    emissions_token: emissions_token,

    pool_fee: convert(pool.fee(), uint256),
    unstaked_fee: convert(pool.unstakedFee(), uint256),
    token0_fees: convert(gauge_fees.token0, uint256),
    token1_fees: convert(gauge_fees.token1, uint256),

    # todo: populate real ALM data when ALM contracts are ready
    alm_vault: empty(address),
    alm_reserve0: 0,
    alm_reserve1: 0,

    positions: positions
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
  pools: DynArray[address[3], MAX_POOLS] = self._pools()
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
  pools: DynArray[address[3], MAX_POOLS] = self._pools()
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
