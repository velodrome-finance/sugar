# SPDX-License-Identifier: BUSL-1.1
# @version ^0.3.6

# @title Velodrome Finance LP Sugar v3
# @author stas, ethzoomer
# @notice Makes it nicer to work with the liquidity pools.

# Structs

MAX_FACTORIES: constant(uint256) = 10
MAX_POOLS: constant(uint256) = 2000
MAX_TOKENS: constant(uint256) = 2000
MAX_LPS: constant(uint256) = 500
MAX_EPOCHS: constant(uint256) = 200
MAX_REWARDS: constant(uint256) = 16
MAX_POSITIONS: constant(uint256) = 10
MAX_PRICES: constant(uint256) = 20
WEEK: constant(uint256) = 7 * 24 * 60 * 60

# Slot0 from CLPool.sol
struct Slot:
  sqrtPriceX96: uint160
  tick: int24
  observationIndex: uint16
  cardinality: uint16
  cardinalityNext: uint16
  unlocked: bool

# GaugeFees from CLPool.sol
struct GaugeFees:
  token0: uint128
  token1: uint128

# Position Principal from Slipstream SugarHelper
struct PositionPrincipal:
  amount0: uint256
  amount1: uint256

# Position from NonfungiblePositionManager.sol (NFT)
struct PositionData:
  nonce: uint96
  operator: address
  poolId: uint80
  tickLower: int24
  tickUpper: int24
  liquidity: uint128
  feeGrowthInside0LastX128: uint256
  feeGrowthInside1LastX128: uint256
  tokensOwed0: uint128
  tokensOwed1: uint128

# Tick.Info from CLPool.sol
struct TickInfo:
  liquidityGross: uint128
  liquidityNet: int128
  stakedLiquidityNet: int128
  feeGrowthOutside0: uint256
  feeGrowthOutside1: uint256
  rewardGrowthOutside: uint256
  tickCumulativeOutside: int56
  secondsPerLiquidityOutside: uint160
  secondsOutside: uint32
  initialized: bool

struct Position:
  id: uint256 # NFT ID on v3, 0 on v2
  liquidity: uint256 # Liquidity amount on v3, amount of LP tokens on v2
  staked: uint256 # liq amount staked on v3, amount of staked LP tokens on v2
  amount0: uint256 # amount of unstaked token0 on both v2 and v3
  amount1: uint256 # amount of unstaked token1 on both v2 and v3
  staked0: uint256 # amount of staked token0 on both v2 and v3
  staked1: uint256 # amount of staked token1 on both v2 and v3
  unstaked_earned0: uint256 # unstaked token0 fees earned on both v2 and v3
  unstaked_earned1: uint256 # unstaked token1 fees earned on both v2 and v3
  emissions_earned: uint256 # staked liq emissions earned on both v2 and v3
  tick_lower: int24 # Position lower tick on v3, 0 on v2
  tick_upper: int24 # Position upper tick on v3, 0 on v2
  price_lower: uint160 # Price at lower tick on v3, 0 on v2
  price_upper: uint160 # Price at upper tick on v3, 0 on v2

struct Price:
  tick_price: int24
  liquidity_gross: uint128

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
  pool_fee: uint256

struct Lp:
  lp: address
  symbol: String[100]
  decimals: uint8
  liquidity: uint256

  type: int24 # tick spacing on v3, 0/-1 for stable/volatile on v2
  tick: int24 # current tick on v3, 0 on v2
  price: uint160 # current price on v3, 0 on v2

  token0: address
  reserve0: uint256
  staked0: uint256

  token1: address
  reserve1: uint256
  staked1: uint256

  gauge: address
  gauge_liquidity: uint256
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
  def supplyIndex0(_account: address) -> uint256: view
  def supplyIndex1(_account: address) -> uint256: view
  def index0() -> uint256: view
  def index1() -> uint256: view
  def totalSupply() -> uint256: view
  def symbol() -> String[100]: view
  def decimals() -> uint8: view
  def stable() -> bool: view
  def balanceOf(_account: address) -> uint256: view
  def poolFees() -> address: view
  def gauge() -> address: view # fetches gauge from v3 pool
  def tickSpacing() -> int24: view # v3 tick spacing
  def slot0() -> Slot: view # v3 slot data
  def gaugeFees() -> GaugeFees: view # v3 gauge fees amounts
  def fee() -> uint24: view # v3 fee level
  def unstakedFee() -> uint24: view # v3 unstaked fee level
  def ticks(_tick: int24) -> TickInfo: view # v3 tick data
  def liquidity() -> uint128: view # v3 active liquidity
  def stakedLiquidity() -> uint128: view # v3 active staked liquidity

interface IVoter:
  def gauges(_pool_addr: address) -> address: view
  def gaugeToBribe(_gauge_addr: address) -> address: view
  def gaugeToFees(_gauge_addr: address) -> address: view
  def isAlive(_gauge_addr: address) -> bool: view
  def isWhitelistedToken(_token_addr: address) -> bool: view

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

interface INFPositionManager:
  def positions(_position_id: uint256) -> PositionData: view
  def tokenOfOwnerByIndex(_account: address, _index: uint256) -> uint256: view
  def balanceOf(_account: address) -> uint256: view

interface IReward:
  def getPriorSupplyIndex(_ts: uint256) -> uint256: view
  def supplyCheckpoints(_index: uint256) -> uint256[2]: view
  def tokenRewardsPerEpoch(_token: address, _epstart: uint256) -> uint256: view
  def rewardsListLength() -> uint256: view
  def rewards(_index: uint256) -> address: view
  def earned(_token: address, _venft_id: uint256) -> uint256: view

interface ISlipstreamHelper:
  def getAmountsForLiquidity(_ratio: uint160, _ratioA: uint160, _ratioB: uint160, _liquidity: uint128) -> PositionPrincipal: view
  def getSqrtRatioAtTick(_tick: int24) -> uint160: view
  def principal(_nfpm: address, _position_id: uint256, _ratio: uint160) -> PositionPrincipal: view
  def poolFees(_pool: address, _liquidity: uint128, _current_tick: int24, _lower_tick: int24, _upper_tick: int24) -> PositionPrincipal: view

# Vars
registry: public(IFactoryRegistry)
voter: public(IVoter)
convertor: public(address)
nfpm: public(INFPositionManager)
slipstream_helper: public(ISlipstreamHelper)

# Methods

@external
def __init__(_voter: address, _registry: address, _convertor: address, \
    _nfpm: address, _slipstream_helper: address):
  """
  @dev Sets up our external contract addresses
  """
  self.voter = IVoter(_voter)
  self.registry = IFactoryRegistry(_registry)
  self.nfpm = INFPositionManager(_nfpm)
  self.convertor = _convertor
  self.slipstream_helper = ISlipstreamHelper(_slipstream_helper)

@internal
@view
def _pools(_limit: uint256, _offset: uint256)\
    -> DynArray[address[4], MAX_POOLS]:
  """
  @param _limit The max amount of pools to return
  @param _offset The amount of pools to skip (for optimization)
  @notice Returns a compiled list of pool and its factory and gauge
  @return Array of four addresses (factory, pool, gauge, type value: 0/2/3)
  """
  factories: DynArray[address, MAX_FACTORIES] = self.registry.poolFactories()
  # TODO: Remove
  factories.append(0x77C839b1381C1792A1D5D5ed06F506B2Ff0f4B51)
  factories_count: uint256 = len(factories)

  placeholder: address[4] = empty(address[4])
  to_skip: uint256 = _offset

  pools: DynArray[address[4], MAX_POOLS] = \
    empty(DynArray[address[4], MAX_POOLS])

  for index in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    factory_type: address = empty(address)
    factory: IPoolFactory = IPoolFactory(factories[index])

    if self._is_v2_factory(factory.address):
      factory_type = convert(2, address)
    if self._is_cl_factory(factory.address):
      factory_type = convert(3, address)

    if factory_type == empty(address):
      continue

    pools_count: uint256 = factory.allPoolsLength()

    for pindex in range(0, MAX_POOLS):
      if pindex >= pools_count or len(pools) >= _limit + _offset:
        break

      # Basically skip calls for offset records...
      if to_skip > 0:
        to_skip -= 1
        pools.append(placeholder)
        continue

      pool_addr: address = factory.allPools(pindex)

      if pool_addr == self.convertor:
        continue

      gauge_addr: address = self.voter.gauges(pool_addr)

      pools.append([factory.address, pool_addr, gauge_addr, factory_type])

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
  factories: DynArray[address, MAX_FACTORIES] = self.registry.poolFactories()
  # TODO: Remove
  factories.append(0x77C839b1381C1792A1D5D5ed06F506B2Ff0f4B51)
  factories_count: uint256 = len(factories)

  pools: DynArray[SwapLp, MAX_POOLS] = empty(DynArray[SwapLp, MAX_POOLS])

  for index in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: IPoolFactory = IPoolFactory(factories[index])
    is_cl_factory: bool = self._is_cl_factory(factory.address)
    is_v2_factory: bool = self._is_v2_factory(factory.address)

    if is_v2_factory == False and is_cl_factory == False:
      continue

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
      pool_fee: uint256 = 0

      if is_cl_factory:
        type = pool.tickSpacing()
        reserve0 = IERC20(token0).balanceOf(pool_addr)
        pool_fee = convert(pool.fee(), uint256)
      else:
        if pool.stable():
          type = 0
        reserve0 = pool.reserve0()
        pool_fee = factory.getFee(pool_addr, (type == 0))

      if reserve0 > 0:
        pools.append(SwapLp({
          lp: pool_addr,
          type: type,
          token0: token0,
          token1: token1,
          factory: factory.address,
          pool_fee: pool_fee
        }))

  return pools

@external
@view
def tokens(_limit: uint256, _offset: uint256, _account: address, \
    _addresses: DynArray[address, MAX_TOKENS]) -> DynArray[Token, MAX_TOKENS]:
  """
  @notice Returns a collection of tokens data based on available pools
  @param _limit The max amount of tokens to return
  @param _offset The amount of pools to skip
  @param _account The account to check the balances
  @return Array for Token structs
  """
  pools: DynArray[address[4], MAX_POOLS] = self._pools(_limit, _offset)

  pools_count: uint256 = len(pools)
  addresses_count: uint256 = len(_addresses)
  col: DynArray[Token, MAX_TOKENS] = empty(DynArray[Token, MAX_TOKENS])
  seen: DynArray[address, MAX_TOKENS] = empty(DynArray[address, MAX_TOKENS])

  for index in range(0, MAX_TOKENS):
    if len(col) >= _limit or index >= addresses_count:
      break

    col.append(self._token(_addresses[index], _account))
    seen.append(_addresses[index])

  for index in range(_offset, _offset + MAX_TOKENS):
    if len(col) >= _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]

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
    -> DynArray[Lp, MAX_LPS]:
  """
  @notice Returns a collection of pool data
  @param _limit The max amount of pools to return
  @param _offset The amount of pools to skip
  @param _account The account to check the staked and earned balances
  @return Array for Lp structs
  """
  col: DynArray[Lp, MAX_LPS] = empty(DynArray[Lp, MAX_LPS])
  pools: DynArray[address[4], MAX_POOLS] = self._pools(_limit, _offset)
  pools_count: uint256 = len(pools)

  for index in range(_offset, _offset + MAX_POOLS):
    if len(col) == _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]
    pool: IPool = IPool(pool_data[1])
    token0: address = pool.token0()
    token1: address = pool.token1()

    # If this is a CL factory...
    if convert(3, address) == pool_data[3]:
      col.append(self._byDataCL(pool_data, token0, token1, _account))
    else:
      col.append(self._byData(pool_data, token0, token1, _account))

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
  offset: uint256 = 0

  if (_index > 0):
    offset = _index - 1

  pools: DynArray[address[4], MAX_POOLS] = self._pools(1, offset)

  pool_data: address[4] = pools[_index]
  pool: IPool = IPool(pool_data[1])
  token0: address = pool.token0()
  token1: address = pool.token1()

  # If this is a CL factory...
  if convert(3, address) == pool_data[3]:
    return self._byDataCL(pool_data, token0, token1, _account)

  return self._byData(pool_data, token0, token1, _account)

@internal
@view
def _byData(_data: address[4], _token0: address, _token1: address, \
    _account: address) -> Lp:
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
  pool_liquidity: uint256 = pool.totalSupply()
  gauge_liquidity: uint256 = 0
  emissions: uint256 = 0
  emissions_token: address = empty(address)
  is_stable: bool = pool.stable()
  pool_fee: uint256 = IPoolFactory(_data[0]).getFee(_data[1], is_stable)
  pool_fees: address = pool.poolFees()
  token0: IERC20 = IERC20(_token0)
  token1: IERC20 = IERC20(_token1)
  token0_fees: uint256 = token0.balanceOf(pool_fees)
  token1_fees: uint256 = token1.balanceOf(pool_fees)
  gauge_alive: bool = self.voter.isAlive(gauge.address)
  decimals: uint8 = pool.decimals()
  claimable0: uint256 = 0
  claimable1: uint256 = 0
  acc_balance: uint256 = 0
  reserve0: uint256 = pool.reserve0()
  reserve1: uint256 = pool.reserve1()
  staked0: uint256 = 0
  staked1: uint256 = 0

  type: int24 = -1
  if is_stable:
    type = 0

  if gauge.address != empty(address):
    acc_staked = gauge.balanceOf(_account)
    earned = gauge.earned(_account)
    gauge_liquidity = gauge.totalSupply()
    emissions_token = gauge.rewardToken()

  if gauge_alive:
    emissions = gauge.rewardRate()
    if gauge_liquidity > 0:
      token0_fees = (pool.claimable0(_data[2]) * pool_liquidity) / gauge_liquidity
      token1_fees = (pool.claimable1(_data[2]) * pool_liquidity) / gauge_liquidity
      staked0 = (reserve0 * gauge_liquidity) / pool_liquidity
      staked1 = (reserve1 * gauge_liquidity) / pool_liquidity

  if _account != empty(address):
    acc_balance = pool.balanceOf(_account)
    claimable0 = pool.claimable0(_account)
    claimable1 = pool.claimable1(_account)
    claimable_delta0: uint256 = pool.index0() - pool.supplyIndex0(_account)
    claimable_delta1: uint256 = pool.index1() - pool.supplyIndex1(_account)

    if claimable_delta0 > 0:
      claimable0 += (acc_balance * claimable_delta0) / 10**convert(decimals, uint256)
    if claimable_delta1 > 0:
      claimable1 += (acc_balance * claimable_delta1) / 10**convert(decimals, uint256)

  positions: DynArray[Position, MAX_POSITIONS] = empty(DynArray[Position, MAX_POSITIONS])

  if acc_balance > 0 or acc_staked > 0 or earned > 0 or claimable0 > 0:
    positions.append(
      Position({
        id: 0,
        liquidity: acc_balance,
        staked: acc_staked,
        amount0: (acc_balance * reserve0) / pool_liquidity,
        amount1: (acc_balance * reserve1) / pool_liquidity,
        staked0: (acc_staked * reserve0) / pool_liquidity,
        staked1: (acc_staked * reserve1) / pool_liquidity,
        unstaked_earned0: claimable0,
        unstaked_earned1: claimable1,
        emissions_earned: earned,
        tick_lower: 0,
        tick_upper: 0,
        price_lower: 0,
        price_upper: 0
      })
    )

  return Lp({
    lp: _data[1],
    symbol: pool.symbol(),
    decimals: decimals,
    liquidity: pool_liquidity,

    type: type,
    tick: 0,
    price: 0,

    token0: token0.address,
    reserve0: reserve0,
    staked0: staked0,

    token1: token1.address,
    reserve1: reserve1,
    staked1: staked1,

    gauge: gauge.address,
    gauge_liquidity: gauge_liquidity,
    gauge_alive: gauge_alive,

    fee: self.voter.gaugeToFees(gauge.address),
    bribe: self.voter.gaugeToBribe(gauge.address),
    factory: _data[0],

    emissions: emissions,
    emissions_token: emissions_token,

    pool_fee: pool_fee,
    unstaked_fee: 0,
    token0_fees: token0_fees,
    token1_fees: token1_fees,

    positions: positions
  })

@internal
@view
def _byDataCL(_data: address[4], _token0: address, _token1: address, \
    _account: address) -> Lp:
  """
  @notice Returns CL pool data based on the factory, pool and gauge addresses
  @param _data The addresses to lookup
  @param _account The user account
  @return Lp struct
  """
  pool: IPool = IPool(_data[1])
  gauge: ICLGauge = ICLGauge(_data[2])

  gauge_fees: GaugeFees = pool.gaugeFees()
  gauge_alive: bool = self.voter.isAlive(gauge.address)
  fee_voting_reward: address = empty(address)
  emissions: uint256 = 0
  emissions_token: address = empty(address)
  token0: IERC20 = IERC20(_token0)
  token1: IERC20 = IERC20(_token1)
  positions_count: uint256 = 0
  staked0: uint256 = 0
  staked1: uint256 = 0
  tick_spacing: int24 = pool.tickSpacing()
  pool_liquidity: uint128 = pool.liquidity()
  gauge_liquidity: uint128 = pool.stakedLiquidity()
  token0_fees: uint256 = 0
  token1_fees: uint256 = 0

  slot: Slot = pool.slot0()
  positions: DynArray[Position, MAX_POSITIONS] = \
    empty(DynArray[Position, MAX_POSITIONS])

  if _account != empty(address):
    positions_count = self.nfpm.balanceOf(_account)

  if gauge.address == empty(address):
    unstaked_fees: PositionPrincipal = self.slipstream_helper.poolFees(_data[1], pool_liquidity, slot.tick, slot.tick, slot.tick + tick_spacing)
    token0_fees = unstaked_fees.amount0
    token1_fees = unstaked_fees.amount1
  else:
    fee_voting_reward = gauge.feesVotingReward()
    emissions_token = gauge.rewardToken()

    ratio_a: uint160 = self.slipstream_helper.getSqrtRatioAtTick(slot.tick)
    ratio_b: uint160 = self.slipstream_helper.getSqrtRatioAtTick(slot.tick + tick_spacing)
    tick_staked: PositionPrincipal = self.slipstream_helper.getAmountsForLiquidity(slot.sqrtPriceX96, ratio_a, ratio_b, gauge_liquidity)
    staked0 = tick_staked.amount0
    staked1 = tick_staked.amount1

    staked_fees: PositionPrincipal = self.slipstream_helper.poolFees(_data[1], gauge_liquidity, slot.tick, slot.tick, slot.tick + tick_spacing)
    token0_fees = staked_fees.amount0
    token1_fees = staked_fees.amount1

    if gauge_alive:
      emissions = gauge.rewardRate()

  for index in range(0, MAX_POSITIONS):
    if index >= positions_count:
      break

    position_id: uint256 = self.nfpm.tokenOfOwnerByIndex(_account, index)
    position_data: PositionData = self.nfpm.positions(position_id)
    position_principal: PositionPrincipal = self.slipstream_helper.principal(self.nfpm.address, position_id, slot.sqrtPriceX96)
    position_amount0: uint256 = 0
    position_amount1: uint256 = 0
    position_staked0: uint256 = 0
    position_staked1: uint256 = 0

    emissions_earned: uint256 = 0
    staked: bool = False

    if gauge.address != empty(address):
      emissions_earned = gauge.earned(_account, position_id)
      staked = gauge.stakedContains(_account, position_id)

    if staked:
      position_staked0 = position_principal.amount0
      position_staked1 = position_principal.amount1
    else:
      position_amount0 = position_principal.amount0
      position_amount1 = position_principal.amount1

    positions.append(
      Position({
        id: position_id,
        liquidity: convert(position_data.liquidity, uint256),
        staked: convert(staked, uint256),
        amount0: position_amount0,
        amount1: position_amount1,
        staked0: position_staked0,
        staked1: position_staked1,
        unstaked_earned0: convert(position_data.tokensOwed0, uint256),
        unstaked_earned1: convert(position_data.tokensOwed1, uint256),
        emissions_earned: emissions_earned,
        tick_lower: position_data.tickLower,
        tick_upper: position_data.tickUpper,
        price_lower: self.slipstream_helper.getSqrtRatioAtTick(position_data.tickLower),
        price_upper: self.slipstream_helper.getSqrtRatioAtTick(position_data.tickUpper),
      })
    )

  return Lp({
    lp: pool.address,
    symbol: "",
    decimals: 0,
    liquidity: convert(pool_liquidity, uint256),

    type: tick_spacing,
    tick: slot.tick,
    price: slot.sqrtPriceX96,

    token0: token0.address,
    reserve0: token0.balanceOf(pool.address),
    staked0: staked0,

    token1: token1.address,
    reserve1: token1.balanceOf(pool.address),
    staked1: staked1,

    gauge: gauge.address,
    gauge_liquidity: convert(gauge_liquidity, uint256),
    gauge_alive: gauge_alive,

    fee: fee_voting_reward,
    bribe: self.voter.gaugeToBribe(gauge.address),
    factory: _data[0],

    emissions: emissions,
    emissions_token: emissions_token,

    pool_fee: convert(pool.fee(), uint256),
    unstaked_fee: convert(pool.unstakedFee(), uint256),
    token0_fees: token0_fees,
    token1_fees: token1_fees,

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
  pools: DynArray[address[4], MAX_POOLS] = self._pools(_limit, _offset)
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[LpEpoch, MAX_POOLS] = empty(DynArray[LpEpoch, MAX_POOLS])

  for index in range(_offset, _offset + MAX_POOLS):
    if counted == _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]

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
  pools: DynArray[address[4], MAX_POOLS] = self._pools(_limit, _offset)
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[Reward, MAX_POOLS] = empty(DynArray[Reward, MAX_POOLS])

  for pindex in range(_offset, _offset + MAX_POOLS):
    if counted == _limit or pindex >= pools_count:
      break

    pool_data: address[4] = pools[pindex]
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

@internal
@view
def _is_v2_factory(_factory: address) -> bool:
  """
  @notice Returns true if address is a v2 factory
  @param _factory The factory address
  """
  response: Bytes[32] = raw_call(
      _factory,
      method_id("ZERO_FEE_INDICATOR()"),
      max_outsize=32,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[1]

  return len(response) > 0

@internal
@view
def _is_cl_factory(_factory: address) -> bool:
  """
  @notice Returns true if address is a CL factory
  @param _factory The factory address
  """
  response: Bytes[32] = raw_call(
      _factory,
      method_id("unstakedFeeModule()"),
      max_outsize=32,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[1]

  return len(response) > 0

@external
@view
def prices(_pool: address, _factory: address) -> DynArray[Price, MAX_PRICES]:
  """
  @notice Returns price data at surrounding ticks for a pool
  @param _pool The pool to check price data of
  @param _factory The factory of the pool
  @return Array of Price structs
  """
  if self._is_cl_factory(_factory):
    return self._price(_pool)

  return empty(DynArray[Price, MAX_PRICES])

@internal
@view
def _price(_pool: address) -> DynArray[Price, MAX_PRICES]:
  """
  @notice Returns price data at surrounding ticks for a v3 pool
  @param _pool The pool to check price data of
  @return Array of Price structs
  """
  prices: DynArray[Price, MAX_PRICES] = empty(DynArray[Price, MAX_PRICES])
  pool: IPool = IPool(_pool)
  tick_spacing: int24 = pool.tickSpacing()
  slot: Slot = pool.slot0()

  # fetch liquidity from the ticks surrounding the current tick
  for index in range((-1 * MAX_PRICES / 2), (MAX_PRICES / 2)):
    tick: int24 = slot.tick + (index * tick_spacing)
    tick_info: TickInfo = pool.ticks(tick)

    prices.append(Price({
      tick_price: tick,
      liquidity_gross: tick_info.liquidityGross
    }))

  return prices
