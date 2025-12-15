# SPDX-License-Identifier: BUSL-1.1
# @version ^0.4.0

# @title Velodrome Finance LP Sugar v3
# @author stas, ethzoomer
# @notice Makes it nicer to work with the liquidity pools.

from snekmate.utils import math

# Structs

MAX_TOKENS: public(constant(uint256)) = 2000 # also used for pools count
MAX_LPS: public(constant(uint256)) = 500
MAX_POSITIONS: public(constant(uint256)) = 200
MAX_TOKEN_SYMBOL_LEN: public(constant(uint256)) = 32
MAX_FACTORIES: public(constant(uint256)) = 10
MAX_ITERATIONS: public(constant(uint256)) = 30000

ALM_SCALE: constant(uint256) = as_wei_value(1000, "ether")
MAX_UINT: constant(uint256) = max_value(uint256)

# Slot0 from CLPool.sol
struct Slot:
  sqrtPriceX96: uint160
  tick: int24
  observationIndex: uint16
  cardinality: uint16
  cardinalityNext: uint16
  unlocked: bool

# Observation from CLPool.sol
struct Observation:
  blockTimestamp: uint32
  tickCumulative: int56
  secondsPerLiquidityCumulativeX128: uint160
  initialized: bool

# GaugeFees from CLPool.sol
struct GaugeFees:
  token0: uint128
  token1: uint128

struct Amounts:
  amount0: uint256
  amount1: uint256

struct PoolLauncherPool:
  createdAt: uint32
  pool: address
  poolLauncherToken: address
  tokenToPair: address

struct Token:
  token_address: address
  symbol: String[MAX_TOKEN_SYMBOL_LEN]
  decimals: uint8
  account_balance: uint256
  listed: bool
  emerging: bool

struct SwapLp:
  lp: address
  type: int24 # tick spacing on CL, 0/-1 for stable/volatile on v2
  token0: address
  token1: address
  factory: address
  pool_fee: uint256

struct Lp:
  lp: address
  symbol: String[MAX_TOKEN_SYMBOL_LEN]
  decimals: uint8
  liquidity: uint256

  type: int24 # tick spacing on CL, 0/-1 for stable/volatile on v2
  tick: int24 # current tick on CL, 0 on v2
  sqrt_ratio: uint160 # current sqrtRatio on CL, 0 on v2

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
  emissions_cap: uint256

  pool_fee: uint256 # staked fee % on CL, fee % on v2
  unstaked_fee: uint256 # unstaked fee % on CL, 0 on v2
  token0_fees: uint256
  token1_fees: uint256
  locked0: uint256
  locked1: uint256
  emerging: uint256
  created_at: uint32 # creation timestamp of gaugeless launcher pools

  nfpm: address
  alm: address
  root: address

# Our contracts / Interfaces

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
  def decimals() -> uint8: view
  def stable() -> bool: view
  def balanceOf(_account: address) -> uint256: view
  def poolFees() -> address: view
  def gauge() -> address: view # fetches gauge from CL pool
  def tickSpacing() -> int24: view # CL tick spacing
  def slot0() -> Slot: view # CL slot data
  def gaugeFees() -> GaugeFees: view # CL gauge fees amounts
  def fee() -> uint24: view # CL fee level
  def unstakedFee() -> uint24: view # CL unstaked fee level
  def liquidity() -> uint128: view # CL active liquidity
  def stakedLiquidity() -> uint128: view # CL active staked liquidity
  def factory() -> address: view # CL factory address
  def observations(_index: uint256) -> Observation: view # CL oracle observations
  def feeGrowthGlobal0X128() -> uint256: view # CL token0 fee growth
  def feeGrowthGlobal1X128() -> uint256: view # CL token1 fee growth

interface IGauge:
  def fees0() -> uint256: view
  def fees1() -> uint256: view
  def balanceOf(_account: address) -> uint256: view
  def totalSupply() -> uint256: view
  def rewardRate() -> uint256: view
  def rewardRateByEpoch(_ts: uint256) -> uint256: view
  def rewardToken() -> address: view
  def periodFinish() -> uint256: view

interface ICLGauge:
  def rewards(_position_id: uint256) -> uint256: view
  def rewardRate() -> uint256: view
  def rewardRateByEpoch(_ts: uint256) -> uint256: view
  def rewardToken() -> address: view
  def feesVotingReward() -> address: view
  def periodFinish() -> uint256: view
  def gaugeFactory() -> address: view

interface INFPositionManager:
  def balanceOf(_account: address) -> uint256: view
  def factory() -> address: view

interface ISlipstreamHelper:
  def getAmountsForLiquidity(_ratio: uint160, _ratioA: uint160, _ratioB: uint160, _liquidity: uint128) -> Amounts: view
  def getSqrtRatioAtTick(_tick: int24) -> uint160: view
  def principal(_nfpm: address, _position_id: uint256, _ratio: uint160) -> Amounts: view
  def fees(_nfpm: address, _position_id: uint256) -> Amounts: view
  def poolFees(_pool: address, _liquidity: uint128, _current_tick: int24, _lower_tick: int24, _upper_tick: int24) -> Amounts: view

interface IAlmFactory:
  def poolToWrapper(pool: address) -> address: view
  def core() -> address: view

interface IAlmLpWrapper:
  def previewMint(scale: uint256) -> uint256[2]: view

interface IPoolLauncher:
  def lockerFactory() -> address: view
  def emerging(_pool: address) -> uint256: view
  def pools(_underlyingPool: address) -> PoolLauncherPool: view
  def isPairableToken(_token: address) -> bool: view

interface ILockerFactory:
  def locked(_pool: address) -> uint256: view
  def lockers(_pool: address, _start: uint256, _end: uint256) -> DynArray[address, MAX_POSITIONS]: view

interface ILocker:
  def lp() -> uint256: view

interface ITokenSugar:
  def tokens(_limit: uint256, _offset: uint256, _account: address, _addresses: DynArray[address, MAX_TOKENS]) -> DynArray[Token, MAX_TOKENS]: view
  def safe_balance_of(_token: address, _address: address) -> uint256: view
  def safe_decimals(_token: address) -> uint8: view
  def safe_symbol(_token: address) -> String[MAX_TOKEN_SYMBOL_LEN]: view

interface ILpHelper:
  def pools(_limit: uint256, _offset: uint256, _to_find: address) -> DynArray[address[4], MAX_TOKENS]: view
  def count() -> uint256: view
  def is_root_placeholder_factory(_factory: address) -> bool: view
  def fetch_nfpm(_factory: address) -> address: view
  def voter_gauge_to_incentive(_gauge: address) -> address: view
  def root_lp_address(_factory: address, _token0: address, _token1: address, _type: int24) -> address: view

interface IFactoryRegistry:
  def poolFactories() -> DynArray[address, MAX_FACTORIES]: view

interface IVoter:
  def gauges(_pool_addr: address) -> address: view
  def gaugeToFees(_gauge_addr: address) -> address: view
  def isAlive(_gauge_addr: address) -> bool: view
  def isWhitelistedToken(_token_addr: address) -> bool: view

interface IPoolFactory:
  def allPoolsLength() -> uint256: view
  def allPools(_index: uint256) -> address: view
  def getFee(_pool_addr: address, _stable: bool) -> uint256: view
  def getPool(_token0: address, _token1: address, _fee: int24) -> address: view

# Vars
voter: public(IVoter)
registry: public(IFactoryRegistry)
convertor: public(address)
cl_helper: public(ISlipstreamHelper)
alm_factories: public(DynArray[IAlmFactory, MAX_FACTORIES])
alm_map: public(HashMap[uint256, HashMap[address, address]])
v2_launcher: public(IPoolLauncher)
cl_launcher: public(IPoolLauncher)
token_sugar: public(ITokenSugar)
lp_helper: public(ILpHelper)
v2_locker_factory: public(ILockerFactory)
cl_locker_factory: public(ILockerFactory)

# Methods

@deploy
def __init__(_voter: address, _registry: address, _convertor: address, _slipstream_helper: address,\
    _alm_factories: DynArray[address, MAX_FACTORIES], _v2_launcher: address, _cl_launcher: address, _token_sugar: address, _lp_helper: address):
  """
  @dev Sets up our external contract addresses
  """
  self.voter = IVoter(_voter)
  self.registry = IFactoryRegistry(_registry)
  self.convertor = _convertor
  self.cl_helper = ISlipstreamHelper(_slipstream_helper)
  self.alm_map[57073][0xaC7fC3e9b9d3377a90650fe62B858fF56bD841C9] = 0xFcD4bE2aDb8cdB01e5308Cd96ba06F5b92aebBa1
  self.v2_launcher = IPoolLauncher(_v2_launcher)
  self.cl_launcher = IPoolLauncher(_cl_launcher)
  self.token_sugar = ITokenSugar(_token_sugar)
  self.lp_helper = ILpHelper(_lp_helper)
  if _v2_launcher != empty(address) and _cl_launcher != empty(address):
    self.v2_locker_factory = ILockerFactory(staticcall self.v2_launcher.lockerFactory())
    self.cl_locker_factory = ILockerFactory(staticcall self.cl_launcher.lockerFactory())
  for i: uint256 in range(0, MAX_FACTORIES):
    if i >= len(_alm_factories):
      break
    self.alm_factories.append(IAlmFactory(_alm_factories[i]))

@external
@view
def forSwaps(_limit: uint256, _offset: uint256) -> DynArray[SwapLp, MAX_TOKENS]:
  """
  @notice Returns a compiled list of pools for swaps from pool factories (sans v1)
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip
  @return `SwapLp` structs
  """
  factories: DynArray[address, MAX_FACTORIES] = staticcall self.registry.poolFactories()
  factories_count: uint256 = len(factories)

  pools: DynArray[SwapLp, MAX_TOKENS] = empty(DynArray[SwapLp, MAX_TOKENS])
  to_skip: uint256 = _offset
  left: uint256 = _limit

  for index: uint256 in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: IPoolFactory = IPoolFactory(factories[index])
    if staticcall self.lp_helper.is_root_placeholder_factory(factory.address):
      continue

    nfpm: address = staticcall self.lp_helper.fetch_nfpm(factory.address)
    pools_count: uint256 = staticcall factory.allPoolsLength()

    for pindex: uint256 in range(0, MAX_ITERATIONS):
      if pindex >= pools_count or len(pools) >= MAX_TOKENS:
        break

      # If no pools to process are left...
      if left == 0:
        break

      # Basically skip calls for offset records...
      if to_skip > 0:
        to_skip -= 1
        continue
      else:
        left -= 1

      pool_addr: address = staticcall factory.allPools(pindex)
      pool: IPool = IPool(pool_addr)
      type: int24 = -1
      token0: address = staticcall pool.token0()
      token1: address = staticcall pool.token1()
      reserve0: uint256 = 0
      pool_fee: uint256 = 0

      if nfpm != empty(address):
        type = staticcall pool.tickSpacing()
        reserve0 = staticcall self.token_sugar.safe_balance_of(token0, pool_addr)
        pool_fee = convert(staticcall pool.fee(), uint256)
      else:
        if staticcall pool.stable():
          type = 0
        reserve0 = staticcall pool.reserve0()
        pool_fee = staticcall factory.getFee(pool_addr, (type == 0))

      if reserve0 > 0 or pool_addr == self.convertor:
        pools.append(
          SwapLp(
            lp=pool_addr,
            type=type,
            token0=token0,
            token1=token1,
            factory=factory.address,
            pool_fee=pool_fee
          )
        )

  return pools

@external
@view
def tokens(_limit: uint256, _offset: uint256, _account: address, \
    _addresses: DynArray[address, MAX_TOKENS]) -> DynArray[Token, MAX_TOKENS]:
  """
  @notice Returns a collection of tokens data based on available pools
  @param _limit The max amount of pools to check
  @param _offset The amount of pools to skip
  @param _account The account to check the balances
  @param _addresses Custom tokens to check
  @return Array for Token structs
  """
  return staticcall self.token_sugar.tokens(_limit, _offset, _account, _addresses)

@external
@view
def count() -> uint256:
  """
  @notice Returns total pool count
  @return Total number of pools across all factories
  """
  return staticcall self.lp_helper.count()

@external
@view
def all(_limit: uint256, _offset: uint256, _filter: uint256) -> DynArray[Lp, MAX_LPS]:
  """
  @notice Returns a collection of pool data
  @param _limit The max amount of pools to return
  @param _offset The amount of pools to skip
  @param _filter The category of pools to filter on
  @return Array for Lp structs
  """
  col: DynArray[Lp, MAX_LPS] = empty(DynArray[Lp, MAX_LPS])
  pools: DynArray[address[4], MAX_TOKENS] = \
    staticcall self.lp_helper.pools(_limit, _offset, empty(address))
  pools_count: uint256 = len(pools)

  for index: uint256 in range(0, MAX_TOKENS):
    if len(col) == _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]
    pool: IPool = IPool(pool_data[1])
    token0: address = staticcall pool.token0()
    token1: address = staticcall pool.token1()

    # Minimize gas while filtering pool category
    listed: bool = False
    if _filter == 1 or _filter == 2 or _filter == 4 or _filter == 5:
      if staticcall self.voter.isWhitelistedToken(token0) and \
        staticcall self.voter.isWhitelistedToken(token1):
        listed = True

    emerging: bool = False
    if self.cl_launcher.address != empty(address) and (_filter == 3 or (_filter == 4 and not listed) or (_filter == 5 and not listed)):
      if pool_data[3] != empty(address):
        emerging = staticcall self.cl_launcher.emerging(pool.address) > 0
      else:
        emerging = staticcall self.v2_launcher.emerging(pool.address) > 0

    include: bool = False
    if _filter == 0:
      include = True
    elif _filter == 1:
      include = listed
    elif _filter == 2:
      include = not listed
    elif _filter == 3:
      include = emerging
    elif _filter == 4:
      include = listed or emerging
    elif _filter == 5:
      include = not (listed or emerging)

    if include:
      if pool_data[3] != empty(address):
        col.append(self._cl_lp(pool_data, token0, token1))
      else:
        col.append(self._v2_lp(pool_data, token0, token1))

  return col

@external
@view
def byAddress(_address: address) -> Lp:
  """
  @notice Returns pool data for a specific address
  @param _address The pool address to lookup
  @return Lp struct
  """
  # Limit is max, internal call will return when _address is hit
  pool_data: address[4] = (staticcall self.lp_helper.pools(MAX_ITERATIONS, 0, _address))[0]
  pool: IPool = IPool(pool_data[1])
  token0: address = staticcall pool.token0()
  token1: address = staticcall pool.token1()

  # If this is a CL factory/NFPM present...
  if pool_data[3] != empty(address):
    return self._cl_lp(pool_data, token0, token1)

  return self._v2_lp(pool_data, token0, token1)

@internal
@view
def _v2_lp(_data: address[4], _token0: address, _token1: address) -> Lp:
  """
  @notice Returns pool data based on the factory, pool and gauge addresses
  @param _address The addresses to lookup
  @param _token0 The first token of the pool
  @param _token1 The second token of the pool
  @return Lp struct
  """
  pool: IPool = IPool(_data[1])
  gauge: IGauge = IGauge(_data[2])

  earned: uint256 = 0
  acc_staked: uint256 = 0
  pool_liquidity: uint256 = staticcall pool.totalSupply()
  gauge_liquidity: uint256 = 0
  emissions: uint256 = 0
  emissions_token: address = empty(address)
  is_stable: bool = staticcall pool.stable()
  pool_fee: uint256 = staticcall IPoolFactory(_data[0]).getFee(pool.address, is_stable)
  pool_fees: address = staticcall pool.poolFees()
  token0_fees: uint256 = staticcall self.token_sugar.safe_balance_of(_token0, pool_fees)
  token1_fees: uint256 = staticcall self.token_sugar.safe_balance_of(_token1, pool_fees)
  gauge_alive: bool = staticcall self.voter.isAlive(gauge.address)
  decimals: uint8 = staticcall pool.decimals()
  claimable0: uint256 = 0
  claimable1: uint256 = 0
  acc_balance: uint256 = 0
  reserve0: uint256 = staticcall pool.reserve0()
  reserve1: uint256 = staticcall pool.reserve1()
  staked0: uint256 = 0
  staked1: uint256 = 0
  type: int24 = -1
  locked0: uint256 = 0
  locked1: uint256 = 0
  emerging: uint256 = 0
  created_at: uint32 = 0

  if is_stable:
    type = 0

  if self.v2_launcher.address != empty(address):
    locked: uint256 = staticcall self.v2_locker_factory.locked(_data[1])
    locked0 = (reserve0 * locked) // pool_liquidity
    locked1 = (reserve1 * locked) // pool_liquidity
    emerging = staticcall self.v2_launcher.emerging(_data[1])

  if gauge.address != empty(address):
    gauge_liquidity = staticcall gauge.totalSupply()
    emissions_token = staticcall gauge.rewardToken()
  elif self.v2_launcher.address != empty(address):
    launcher_pool: PoolLauncherPool = staticcall self.v2_launcher.pools(_data[1])

    if launcher_pool.createdAt != 0:
      created_at = launcher_pool.createdAt

      # v2 LP token liquidity is always measured in 18 decimals
      token0_fees = (staticcall pool.index0() * pool_liquidity) // (10**18)
      token1_fees = (staticcall pool.index1() * pool_liquidity) // (10**18)

  if gauge_alive and staticcall gauge.periodFinish() > block.timestamp:
    emissions = staticcall gauge.rewardRate()
    if gauge_liquidity > 0:
      token0_fees = (staticcall pool.claimable0(_data[2]) * pool_liquidity) // gauge_liquidity
      token1_fees = (staticcall pool.claimable1(_data[2]) * pool_liquidity) // gauge_liquidity
      staked0 = (reserve0 * gauge_liquidity) // pool_liquidity
      staked1 = (reserve1 * gauge_liquidity) // pool_liquidity

  return Lp(
    lp=_data[1],
    symbol=staticcall self.token_sugar.safe_symbol(pool.address),
    decimals=decimals,
    liquidity=pool_liquidity,

    type=type,
    tick=0,
    sqrt_ratio=0,

    token0=_token0,
    reserve0=reserve0,
    staked0=staked0,

    token1=_token1,
    reserve1=reserve1,
    staked1=staked1,

    gauge=gauge.address,
    gauge_liquidity=gauge_liquidity,
    gauge_alive=gauge_alive,

    fee=staticcall self.voter.gaugeToFees(gauge.address),
    bribe=staticcall self.lp_helper.voter_gauge_to_incentive(gauge.address),
    factory=_data[0],

    emissions=emissions,
    emissions_token=emissions_token,
    emissions_cap=0,

    pool_fee=pool_fee,
    unstaked_fee=0,
    token0_fees=token0_fees,
    token1_fees=token1_fees,
    locked0=locked0,
    locked1=locked1,
    emerging=emerging,
    created_at=created_at,

    nfpm=empty(address),
    alm=empty(address),

    root=staticcall self.lp_helper.root_lp_address(_data[0], _token0, _token1, type)
  )

@internal
@view
def _cl_lp(_data: address[4], _token0: address, _token1: address) -> Lp:
  """
  @notice Returns CL pool data based on the factory, pool and gauge addresses
  @param _data The addresses to lookup
  @param _token0 The first token of the pool
  @param _token1 The second token of the pool
  @return Lp struct
  """
  pool: IPool = IPool(_data[1])
  gauge: ICLGauge = ICLGauge(_data[2])

  gauge_alive: bool = staticcall self.voter.isAlive(gauge.address)
  fee_voting_reward: address = empty(address)
  emissions: uint256 = 0
  emissions_token: address = empty(address)
  emissions_cap: uint256 = 0
  staked0: uint256 = 0
  staked1: uint256 = 0
  tick_spacing: int24 = staticcall pool.tickSpacing()
  pool_liquidity: uint128 = staticcall pool.liquidity()
  gauge_liquidity: uint128 = staticcall pool.stakedLiquidity()
  token0_fees: uint256 = 0
  token1_fees: uint256 = 0
  locked0: uint256 = 0
  locked1: uint256 = 0
  emerging: uint256 = 0
  created_at: uint32 = 0

  slot: Slot = staticcall pool.slot0()
  tick_low: int24 = (slot.tick // tick_spacing) * tick_spacing
  tick_high: int24 = tick_low + tick_spacing

  if self.cl_launcher.address != empty(address):
    lockers: DynArray[address, MAX_POSITIONS] = staticcall self.cl_locker_factory.lockers(_data[1], 0, MAX_POSITIONS)
    lockers_count: uint256 = len(lockers)

    # compute total amount of locked tokens
    for i: uint256 in range(0, MAX_POSITIONS):
      if i >= lockers_count or lockers[i] == empty(address):
        break

      locker: ILocker = ILocker(lockers[i])
      locker_pos_id: uint256 = staticcall locker.lp()

      amounts: Amounts = staticcall self.cl_helper.principal(
        _data[3], locker_pos_id, slot.sqrtPriceX96
      )
      locked0 += amounts.amount0
      locked1 += amounts.amount1

    emerging = staticcall self.cl_launcher.emerging(_data[1])

    if gauge.address != empty(address):
      gauge_factory: address = staticcall gauge.gaugeFactory()
      emissions_cap = self._safe_emissions_cap(_data[2], gauge_factory)

  if gauge.address == empty(address):
    if self.cl_launcher.address != empty(address):
      launcher_pool: PoolLauncherPool = staticcall self.cl_launcher.pools(_data[1])

      if launcher_pool.createdAt != 0:
        created_at = launcher_pool.createdAt

        obs_index: uint256 = convert(slot.observationIndex, uint256)
        obs: Observation = staticcall pool.observations(obs_index)

        # compute time delta and seconds per liquidity delta
        # beginning of delta is assigned as created_at timestamp, with 0 splc
        time_delta: uint256 = convert((obs.blockTimestamp - created_at), uint256)
        splc_delta: uint256 = convert(obs.secondsPerLiquidityCumulativeX128, uint256)

        if splc_delta != 0:
          historical_liquidity: uint256 = (time_delta << 128) // splc_delta

          token0_fees = (staticcall pool.feeGrowthGlobal0X128() * historical_liquidity) // (1 << 128)
          token1_fees = (staticcall pool.feeGrowthGlobal1X128() * historical_liquidity) // (1 << 128)
  elif gauge_liquidity > 0:
    fee_voting_reward = staticcall gauge.feesVotingReward()
    emissions_token = staticcall gauge.rewardToken()

    ratio_a: uint160 = staticcall self.cl_helper.getSqrtRatioAtTick(tick_low)
    ratio_b: uint160 = staticcall self.cl_helper.getSqrtRatioAtTick(tick_high)
    staked_amounts: Amounts = staticcall self.cl_helper.getAmountsForLiquidity(
      slot.sqrtPriceX96, ratio_a, ratio_b, gauge_liquidity
    )
    staked0 = staked_amounts.amount0
    staked1 = staked_amounts.amount1

    gauge_fees: GaugeFees = staticcall pool.gaugeFees()

    token0_fees = convert(gauge_fees.token0, uint256)
    token1_fees = convert(gauge_fees.token1, uint256)

  if gauge_alive and staticcall gauge.periodFinish() > block.timestamp:
    emissions = staticcall gauge.rewardRate()

  alm_wrapper: address = empty(address)
  for i: uint256 in range(0, MAX_FACTORIES):
    if i >= len(self.alm_factories):
      break
    alm_wrapper = self._alm_pool_to_wrapper(pool.address, i)
    if alm_wrapper != empty(address):
      break

  return Lp(
    lp=pool.address,
    symbol="",
    decimals=18,
    liquidity=convert(pool_liquidity, uint256),

    type=tick_spacing,
    tick=slot.tick,
    sqrt_ratio=slot.sqrtPriceX96,

    token0=_token0,
    reserve0=staticcall self.token_sugar.safe_balance_of(_token0, pool.address),
    staked0=staked0,

    token1=_token1,
    reserve1=staticcall self.token_sugar.safe_balance_of(_token1, pool.address),
    staked1=staked1,

    gauge=gauge.address,
    gauge_liquidity=convert(gauge_liquidity, uint256),
    gauge_alive=gauge_alive,

    fee=fee_voting_reward,
    bribe=staticcall self.lp_helper.voter_gauge_to_incentive(gauge.address),
    factory=_data[0],

    emissions=emissions,
    emissions_token=emissions_token,
    emissions_cap=emissions_cap,

    pool_fee=convert(staticcall pool.fee(), uint256),
    unstaked_fee=convert(staticcall pool.unstakedFee(), uint256),
    token0_fees=token0_fees,
    token1_fees=token1_fees,
    locked0=locked0,
    locked1=locked1,
    emerging=emerging,
    created_at=created_at,

    nfpm=_data[3],
    alm=alm_wrapper,

    root=staticcall self.lp_helper.root_lp_address(_data[0], _token0, _token1, tick_spacing),
  )

@internal
@view
def _safe_emissions_cap(_gauge: address, _factory: address) -> uint256:
  response: Bytes[32] = raw_call(
      _factory,
      abi_encode(_gauge, method_id=method_id("emissionsCaps(address)")),
      max_outsize=32,
      gas=100000,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[1]

  if len(response) > 0:
    return (abi_decode(response, uint256))

  return 0

@internal
@view
def _alm_pool_to_wrapper(_pool: address, _factory_index: uint256) -> address:
  """
  @notice Returns the ALM wrapper for the given pool
  @param _pool The pool to return the wrapper for
  @param _factory_index The ALM factory to use
  """
  mapped_wrapper: address = self.alm_map[chain.id][_pool]
  if mapped_wrapper != empty(address):
    return mapped_wrapper
  return staticcall self.alm_factories[_factory_index].poolToWrapper(_pool)

@external
@view
def almEstimateAmounts(
  _wrapper: address,
  _amount0: uint256,
  _amount1: uint256
) -> uint256[3]:
  """
  @notice Estimates the ALM amounts and LP tokens for a deposit
  @param _wrapper The LP Wrapper contract
  @param _amount0 First token amount
  @param _amount1 Second token amount
  @return Returns an array of tokens and LP amounts
  """
  targets: uint256[2] = staticcall IAlmLpWrapper(_wrapper).previewMint(ALM_SCALE)

  lp_amount: uint256 = min(
      MAX_UINT if (targets[0] == 0) else math._mul_div(_amount0, ALM_SCALE, targets[0], False),
      MAX_UINT if (targets[1] == 0) else math._mul_div(_amount1, ALM_SCALE, targets[1], False)
  )

  max0: uint256 = 0 if (targets[0] == 0) else math._mul_div(targets[0], lp_amount, ALM_SCALE, True)
  max1: uint256 = 0 if (targets[1] == 0) else math._mul_div(targets[1], lp_amount, ALM_SCALE, True)

  return [max0, max1, lp_amount]
