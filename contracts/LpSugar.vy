# SPDX-License-Identifier: BUSL-1.1
# @version ^0.4.0

# @title Velodrome Finance LP Sugar v3
# @author stas, ethzoomer
# @notice Makes it nicer to work with the liquidity pools.

from modules import lp_shared
from snekmate.utils import math

initializes: lp_shared

# Structs

MAX_TOKENS: public(constant(uint256)) = 2000
MAX_LPS: public(constant(uint256)) = 500
MAX_POSITIONS: public(constant(uint256)) = 200
MAX_TOKEN_SYMBOL_LEN: public(constant(uint256)) = 32

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

# Position from NonfungiblePositionManager.sol (NFT)
struct PositionData:
  nonce: uint96
  operator: address
  token0: address
  token1: address
  tickSpacing: uint24
  tickLower: int24
  tickUpper: int24
  liquidity: uint128
  feeGrowthInside0LastX128: uint256
  feeGrowthInside1LastX128: uint256
  tokensOwed0: uint128
  tokensOwed1: uint128

struct Position:
  id: uint256 # NFT ID on CL, 0 on v2
  lp: address
  liquidity: uint256 # Liquidity amount on CL, amount of LP tokens on v2
  staked: uint256 # liq amount staked on CL, amount of staked LP tokens on v2
  amount0: uint256 # amount of unstaked token0 on both v2 and CL
  amount1: uint256 # amount of unstaked token1 on both v2 and CL
  staked0: uint256 # amount of staked token0 on both v2 and CL
  staked1: uint256 # amount of staked token1 on both v2 and CL
  unstaked_earned0: uint256 # unstaked token0 fees earned on both v2 and CL
  unstaked_earned1: uint256 # unstaked token1 fees earned on both v2 and CL
  emissions_earned: uint256 # staked liq emissions earned on both v2 and CL
  tick_lower: int24 # Position lower tick on CL, 0 on v2
  tick_upper: int24 # Position upper tick on CL, 0 on v2
  sqrt_ratio_lower: uint160 # sqrtRatio at lower tick on CL, 0 on v2
  sqrt_ratio_upper: uint160 # sqrtRatio at upper tick on CL, 0 on v2
  locker: address # locker address for locked liquidity, 0 otherwise
  unlocks_at: uint32 # unlock timestamp for locked liquidity, 0 otherwise
  alm: address

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

  pool_fee: uint256 # staked fee % on CL, fee % on v2
  unstaked_fee: uint256 # unstaked fee % on CL, 0 on v2
  token0_fees: uint256
  token1_fees: uint256
  locked: uint256
  emerging: uint256
  created_at: uint32 # creation timestamp of gaugeless launcher pools

  nfpm: address
  alm: address
  root: address

# See:
#   https://github.com/mellow-finance/mellow-alm-toolkit/blob/main/src/interfaces/ICore.sol#L71-L120
struct AlmManagedPositionInfo:
  slippageD9: uint32
  property: uint24
  owner: address
  pool: address
  ammPositionIds: DynArray[uint256, 10]
  # ...Params removed as we don't use those

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
  def earned(_account: address) -> uint256: view
  def balanceOf(_account: address) -> uint256: view
  def totalSupply() -> uint256: view
  def rewardRate() -> uint256: view
  def rewardRateByEpoch(_ts: uint256) -> uint256: view
  def rewardToken() -> address: view
  def periodFinish() -> uint256: view

interface ICLGauge:
  def earned(_account: address, _position_id: uint256) -> uint256: view
  def rewards(_position_id: uint256) -> uint256: view
  def rewardRate() -> uint256: view
  def rewardRateByEpoch(_ts: uint256) -> uint256: view
  def rewardToken() -> address: view
  def feesVotingReward() -> address: view
  def stakedContains(_account: address, _position_id: uint256) -> bool: view
  def stakedValues(_account: address) -> DynArray[uint256, MAX_POSITIONS]: view
  def periodFinish() -> uint256: view

interface INFPositionManager:
  def positions(_position_id: uint256) -> PositionData: view
  def tokenOfOwnerByIndex(_account: address, _index: uint256) -> uint256: view
  def balanceOf(_account: address) -> uint256: view
  def factory() -> address: view
  def userPositions(_account: address, _pool: address) -> DynArray[uint256, MAX_POSITIONS]: view

interface ISlipstreamHelper:
  def getAmountsForLiquidity(_ratio: uint160, _ratioA: uint160, _ratioB: uint160, _liquidity: uint128) -> Amounts: view
  def getSqrtRatioAtTick(_tick: int24) -> uint160: view
  def principal(_nfpm: address, _position_id: uint256, _ratio: uint160) -> Amounts: view
  def fees(_nfpm: address, _position_id: uint256) -> Amounts: view
  def poolFees(_pool: address, _liquidity: uint128, _current_tick: int24, _lower_tick: int24, _upper_tick: int24) -> Amounts: view

interface IAlmFactory:
  def poolToWrapper(pool: address) -> address: view
  def core() -> address: view

interface IAlmCore:
  def managedPositionAt(_id: uint256) -> AlmManagedPositionInfo: view

interface IAlmLpWrapper:
  def positionId() -> uint256: view
  def previewMint(scale: uint256) -> uint256[2]: view

interface IPoolLauncher:
  def lockerFactory() -> address: view
  def emerging(_pool: address) -> uint256: view
  def pools(_underlyingPool: address) -> PoolLauncherPool: view
  def isPairableToken(_token: address) -> bool: view

interface ILockerFactory:
  def locked(_pool: address) -> uint256: view
  def lockersPerPoolPerUser(_pool: address, _user: address) -> DynArray[address, MAX_POSITIONS]: view

interface ILocker:
  def lockedUntil() -> uint32: view
  def lp() -> uint256: view

interface ITokenSugar:
  def tokens(_limit: uint256, _offset: uint256, _account: address, _addresses: DynArray[address, MAX_TOKENS]) -> DynArray[Token, MAX_TOKENS]: view
  def safe_balance_of(_token: address, _address: address) -> uint256: view
  def safe_decimals(_token: address) -> uint8: view
  def safe_symbol(_token: address) -> String[MAX_TOKEN_SYMBOL_LEN]: view

# Vars
cl_helper: public(ISlipstreamHelper)
alm_factory: public(IAlmFactory)
alm_map: public(HashMap[uint256, HashMap[address, address]])
v2_launcher: public(IPoolLauncher)
cl_launcher: public(IPoolLauncher)
token_sugar: public(ITokenSugar)

# Methods

@deploy
def __init__(_voter: address, _registry: address, _convertor: address, _slipstream_helper: address,\
    _alm_factory: address, _v2_launcher: address, _cl_launcher: address, _token_sugar: address):
  """
  @dev Sets up our external contract addresses
  """
  self.cl_helper = ISlipstreamHelper(_slipstream_helper)
  self.alm_factory = IAlmFactory(_alm_factory)
  self.alm_map[57073][0xaC7fC3e9b9d3377a90650fe62B858fF56bD841C9] = 0xFcD4bE2aDb8cdB01e5308Cd96ba06F5b92aebBa1
  self.v2_launcher = IPoolLauncher(_v2_launcher)
  self.cl_launcher = IPoolLauncher(_cl_launcher)
  self.token_sugar = ITokenSugar(_token_sugar)

  # Modules...
  lp_shared.__init__(_voter, _registry, _convertor)

@external
@view
def forSwaps(_limit: uint256, _offset: uint256) -> DynArray[SwapLp, lp_shared.MAX_POOLS]:
  """
  @notice Returns a compiled list of pools for swaps from pool factories (sans v1)
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip
  @return `SwapLp` structs
  """
  factories: DynArray[address, lp_shared.MAX_FACTORIES] = staticcall lp_shared.registry.poolFactories()
  factories_count: uint256 = len(factories)

  pools: DynArray[SwapLp, lp_shared.MAX_POOLS] = empty(DynArray[SwapLp, lp_shared.MAX_POOLS])
  to_skip: uint256 = _offset
  left: uint256 = _limit

  for index: uint256 in range(0, lp_shared.MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: lp_shared.IPoolFactory = lp_shared.IPoolFactory(factories[index])
    if lp_shared._is_root_placeholder_factory(factory.address):
      continue

    nfpm: address = lp_shared._fetch_nfpm(factory.address)
    pools_count: uint256 = staticcall factory.allPoolsLength()

    for pindex: uint256 in range(0, lp_shared.MAX_ITERATIONS):
      if pindex >= pools_count or len(pools) >= lp_shared.MAX_POOLS:
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

      if reserve0 > 0 or pool_addr == lp_shared.convertor:
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
  return lp_shared._count()

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
  pools: DynArray[address[4], lp_shared.MAX_POOLS] = \
    lp_shared._pools(_limit, _offset, empty(address))
  pools_count: uint256 = len(pools)

  for index: uint256 in range(0, lp_shared.MAX_POOLS):
    if len(col) == _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]
    pool: IPool = IPool(pool_data[1])
    token0: address = staticcall pool.token0()
    token1: address = staticcall pool.token1()

    # Minimize gas while filtering pool category
    listed: bool = False
    if _filter == 1 or _filter == 2 or _filter == 4 or _filter == 5:
      if staticcall lp_shared.voter.isWhitelistedToken(token0) and \
        staticcall lp_shared.voter.isWhitelistedToken(token1):
        listed = True

    emerging: bool = False
    if _filter == 3 or (_filter == 4 and not listed) or (_filter == 5 and not listed):
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
  pool_data: address[4] = \
    lp_shared._pools(lp_shared.MAX_ITERATIONS, 0, _address)[0]
  pool: IPool = IPool(pool_data[1])
  token0: address = staticcall pool.token0()
  token1: address = staticcall pool.token1()

  # If this is a CL factory/NFPM present...
  if pool_data[3] != empty(address):
    return self._cl_lp(pool_data, token0, token1)

  return self._v2_lp(pool_data, token0, token1)


@external
@view
def byIndex(_index: uint256) -> Lp:
  """
  @notice Returns pool data at a specific stored index
  @param _index The index to lookup
  @return Lp struct
  """
  # Basically index is the offset and the limit is always one...
  # This will fire if _index is out of bounds
  pool_data: address[4] = lp_shared._pools(1, _index, empty(address))[0]
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
  locker_factory: ILockerFactory = ILockerFactory(staticcall self.v2_launcher.lockerFactory())

  earned: uint256 = 0
  acc_staked: uint256 = 0
  pool_liquidity: uint256 = staticcall pool.totalSupply()
  gauge_liquidity: uint256 = 0
  emissions: uint256 = 0
  emissions_token: address = empty(address)
  is_stable: bool = staticcall pool.stable()
  pool_fee: uint256 = staticcall lp_shared.IPoolFactory(_data[0]).getFee(pool.address, is_stable)
  pool_fees: address = staticcall pool.poolFees()
  token0_fees: uint256 = staticcall self.token_sugar.safe_balance_of(_token0, pool_fees)
  token1_fees: uint256 = staticcall self.token_sugar.safe_balance_of(_token1, pool_fees)
  gauge_alive: bool = staticcall lp_shared.voter.isAlive(gauge.address)
  decimals: uint8 = staticcall pool.decimals()
  claimable0: uint256 = 0
  claimable1: uint256 = 0
  acc_balance: uint256 = 0
  reserve0: uint256 = staticcall pool.reserve0()
  reserve1: uint256 = staticcall pool.reserve1()
  staked0: uint256 = 0
  staked1: uint256 = 0
  type: int24 = -1
  locked: uint256 = staticcall locker_factory.locked(_data[1])
  emerging: uint256 = staticcall self.v2_launcher.emerging(_data[1])
  created_at: uint32 = 0

  if is_stable:
    type = 0

  if gauge.address != empty(address):
    gauge_liquidity = staticcall gauge.totalSupply()
    emissions_token = staticcall gauge.rewardToken()
  else:
    launcher_pool: PoolLauncherPool = staticcall self.v2_launcher.pools(_data[1])

    if launcher_pool.createdAt != 0:
      created_at = launcher_pool.createdAt
      token0_fees = staticcall pool.index0()
      token1_fees = staticcall pool.index1()

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

    fee=staticcall lp_shared.voter.gaugeToFees(gauge.address),
    bribe=lp_shared._voter_gauge_to_incentive(gauge.address),
    factory=_data[0],

    emissions=emissions,
    emissions_token=emissions_token,

    pool_fee=pool_fee,
    unstaked_fee=0,
    token0_fees=token0_fees,
    token1_fees=token1_fees,
    locked=locked,
    emerging=emerging,
    created_at=created_at,

    nfpm=empty(address),
    alm=empty(address),

    root=lp_shared._root_lp_address(_data[0], _token0, _token1, type)
  )

@external
@view
def positions(_limit: uint256, _offset: uint256, _account: address)\
    -> DynArray[Position, MAX_POSITIONS]:
  """
  @notice Returns a collection of positions
  @param _account The account to fetch positions for
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip (for optimization)
  @return Array for Lp structs
  """
  factories: DynArray[address, lp_shared.MAX_FACTORIES] = staticcall lp_shared.registry.poolFactories()

  return self._positions(_limit, _offset, _account, factories)

@external
@view
def positionsByFactory(
    _limit: uint256,
    _offset: uint256,
    _account: address,
    _factory: address
) -> DynArray[Position, MAX_POSITIONS]:
  """
  @notice Returns a collection of positions for the given factory
  @param _account The account to fetch positions for
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip (for optimization)
  @param _factory The INFPositionManager address used to fetch positions
  @return Array for Lp structs
  """
  return self._positions(_limit, _offset, _account, [_factory])

@internal
@view
def _positions(
  _limit: uint256,
  _offset: uint256,
  _account: address,
  _factories: DynArray[address, lp_shared.MAX_FACTORIES]
) -> DynArray[Position, MAX_POSITIONS]:
  """
  @notice Returns a collection of positions for a set of factories
  @param _account The account to fetch positions for
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip (for optimization)
  @param _factories The factories to fetch from
  @return Array for Lp structs
  """
  positions: DynArray[Position, MAX_POSITIONS] = \
    empty(DynArray[Position, MAX_POSITIONS])

  if _account == empty(address):
    return positions

  to_skip: uint256 = _offset
  pools_done: uint256 = 0

  factories_count: uint256 = len(_factories)

  alm_core: IAlmCore = empty(IAlmCore)
  if self.alm_factory != empty(IAlmFactory):
    alm_core = IAlmCore(staticcall self.alm_factory.core())

  for index: uint256 in range(0, lp_shared.MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: lp_shared.IPoolFactory = lp_shared.IPoolFactory(_factories[index])

    if lp_shared._is_root_placeholder_factory(factory.address):
      continue

    pools_count: uint256 = staticcall factory.allPoolsLength()

    nfpm: INFPositionManager = \
      INFPositionManager(lp_shared._fetch_nfpm(factory.address))

    # V2/Basic pool
    if nfpm.address == empty(address):
      for pindex: uint256 in range(0, lp_shared.MAX_ITERATIONS):
        if pindex >= pools_count or pools_done >= _limit:
          break

        # Basically skip calls for offset records...
        if to_skip > 0:
          to_skip -= 1
          continue
        else:
          pools_done += 1

        pool_addr: address = staticcall factory.allPools(pindex)

        if pool_addr == lp_shared.convertor:
          continue

        pos: Position = self._v2_position(_account, pool_addr, empty(address))

        if pos.lp != empty(address):
          if len(positions) < MAX_POSITIONS:
            positions.append(pos)
          else:
            break

        # Fetch locked V2/Basic positions
        v2_locker_factory: ILockerFactory = ILockerFactory(staticcall self.v2_launcher.lockerFactory())
        lockers: DynArray[address, MAX_POSITIONS] = staticcall v2_locker_factory.lockersPerPoolPerUser(pool_addr, _account)

        for lindex: uint256 in range(0, MAX_POSITIONS):
          if lindex >= len(lockers):
            break

          locker: ILocker = ILocker(lockers[lindex])
          locked_pos: Position = self._v2_position(
            _account,
            pool_addr,
            lockers[lindex]
          )

          if len(positions) < MAX_POSITIONS:
            positions.append(locked_pos)
          else:
            break

    else:
      # Fetch CL positions
      for pindex: uint256 in range(0, lp_shared.MAX_POOLS):
        if pindex >= pools_count or pools_done >= _limit:
          break

        # Basically skip calls for offset records...
        if to_skip > 0:
          to_skip -= 1
          continue
        else:
          pools_done += 1

        pool_addr: address = staticcall factory.allPools(pindex)
        gauge: ICLGauge = ICLGauge(staticcall lp_shared.voter.gauges(pool_addr))
        staked: bool = False

        # Fetch unstaked CL positions if supported,
        # else see `positionsUnstakedConcentrated()`
        user_pos_ids: DynArray[uint256, MAX_POSITIONS] = \
          empty(DynArray[uint256, MAX_POSITIONS])

        if self._has_userPositions(nfpm.address):
          user_pos_ids = staticcall nfpm.userPositions(_account, pool_addr)

        for upindex: uint256 in range(0, MAX_POSITIONS):
          if upindex >= len(user_pos_ids):
            break

          pos: Position = self._cl_position(
            user_pos_ids[upindex],
            _account,
            pool_addr,
            gauge.address,
            factory.address,
            nfpm.address,
            empty(address)
          )

          if len(positions) < MAX_POSITIONS:
            positions.append(pos)
          else:
            break

        # Fetch staked CL positions
        if gauge.address != empty(address):
          staked_position_ids: DynArray[uint256, MAX_POSITIONS] = \
            staticcall gauge.stakedValues(_account)

          for sindex: uint256 in range(0, MAX_POSITIONS):
            if sindex >= len(staked_position_ids):
              break

            pos: Position = self._cl_position(
              staked_position_ids[sindex],
              _account,
              pool_addr,
              gauge.address,
              factory.address,
              nfpm.address,
              empty(address)
            )

            if len(positions) < MAX_POSITIONS:
              positions.append(pos)
            else:
              break

        # Fetch locked CL positions
        cl_locker_factory: ILockerFactory = ILockerFactory(staticcall self.cl_launcher.lockerFactory())
        lockers: DynArray[address, MAX_POSITIONS] = staticcall cl_locker_factory.lockersPerPoolPerUser(pool_addr, _account)

        for lindex: uint256 in range(0, MAX_POSITIONS):
          if lindex >= len(lockers):
            break

          locker: ILocker = ILocker(lockers[lindex])
          pos: Position = self._cl_position(
            staticcall locker.lp(),
            _account,
            pool_addr,
            gauge.address,
            factory.address,
            nfpm.address,
            lockers[lindex]
          )

          if len(positions) < MAX_POSITIONS:
            positions.append(pos)
          else:
            break

        # Next, continue with fetching the ALM positions!
        if self.alm_factory == empty(IAlmFactory):
          continue

        alm_staking: IGauge = IGauge(
          self._alm_pool_to_wrapper(pool_addr)
        )

        if alm_staking.address == empty(address):
          continue

        alm_user_liq: uint256 = staticcall alm_staking.balanceOf(_account)

        if alm_user_liq == 0:
          continue

        alm_pos: AlmManagedPositionInfo = staticcall alm_core.managedPositionAt(
          staticcall IAlmLpWrapper(alm_staking.address).positionId()
        )

        if gauge.address != empty(address) and len(alm_pos.ammPositionIds) > 0:
          staked = staticcall gauge.stakedContains(
            alm_core.address, alm_pos.ammPositionIds[0]
          )

        pos: Position = self._cl_position(
          alm_pos.ammPositionIds[0],
          # Account is the ALM Core contract here...
          alm_core.address,
          pool_addr,
          gauge.address if staked else empty(address),
          factory.address,
          nfpm.address,
          empty(address)
        )

        # For the Temper strategy we might have a second position to add up
        if len(alm_pos.ammPositionIds) > 1:
          pos2: Position = self._cl_position(
            alm_pos.ammPositionIds[1],
            # Account is the ALM Core contract here...
            alm_core.address,
            pool_addr,
            gauge.address if staked else empty(address),
            factory.address,
            nfpm.address,
            empty(address)
          )
          pos.amount0 += pos2.amount0
          pos.amount1 += pos2.amount1
          pos.staked0 += pos2.staked0
          pos.staked1 += pos2.staked1

        alm_liq: uint256 = staticcall alm_staking.totalSupply()
        # adjust user share of the vault...
        pos.amount0 = (alm_user_liq * pos.amount0) // alm_liq
        pos.amount1 = (alm_user_liq * pos.amount1) // alm_liq
        pos.staked0 = (alm_user_liq * pos.staked0) // alm_liq
        pos.staked1 = (alm_user_liq * pos.staked1) // alm_liq

        # ignore dust as the rebalancing might report "fees"
        pos.unstaked_earned0 = 0
        pos.unstaked_earned1 = 0

        pos.emissions_earned = staticcall alm_staking.earned(_account)
        # ALM liquidity is fully staked
        pos.liquidity = 0
        pos.staked = alm_user_liq
        pos.alm = alm_staking.address

        if len(positions) < MAX_POSITIONS:
          positions.append(pos)
        else:
          break

  return positions

@external
@view
def positionsUnstakedConcentrated(
  _limit: uint256,
  _offset: uint256,
  _account: address
) -> DynArray[Position, MAX_POSITIONS]:
  """
  @notice Returns a collection of unstaked CL positions (legacy)
  @param _account The account to fetch positions for
  @param _limit The max amount of positions to process
  @param _offset The amount of positions to skip
  @return Array for Position structs
  """
  positions: DynArray[Position, MAX_POSITIONS] = \
    empty(DynArray[Position, MAX_POSITIONS])

  if _account == empty(address):
    return positions

  factories: DynArray[address, lp_shared.MAX_FACTORIES] = \
    staticcall lp_shared.registry.poolFactories()

  to_skip: uint256 = _offset
  positions_done: uint256 = 0
  factories_count: uint256 = len(factories)

  for index: uint256 in range(0, lp_shared.MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: lp_shared.IPoolFactory = lp_shared.IPoolFactory(factories[index])

    nfpm: INFPositionManager = \
      INFPositionManager(lp_shared._fetch_nfpm(factory.address))

    if nfpm.address == empty(address):
      continue

    if lp_shared._is_root_placeholder_factory(factory.address):
      continue

    # Handled in `positions()`
    if self._has_userPositions(nfpm.address):
      continue

    positions_count: uint256 = staticcall nfpm.balanceOf(_account)

    for pindex: uint256 in range(0, MAX_POSITIONS):
      if pindex >= positions_count:
        break

      if pindex >= positions_count or positions_done >= _limit:
        break

      # Basically skip calls for offset records...
      if to_skip > 0:
        to_skip -= 1
        continue
      else:
        positions_done += 1

      pos_id: uint256 = staticcall nfpm.tokenOfOwnerByIndex(_account, pindex)
      pos: Position = self._cl_position(
        pos_id,
        _account,
        empty(address),
        empty(address),
        factory.address,
        nfpm.address,
        empty(address)
      )

      if pos.lp != empty(address):
        if len(positions) < MAX_POSITIONS:
          positions.append(pos)
        else:
          break

  return positions

@internal
@view
def _cl_position(
    _id: uint256,
    _account: address,
    _pool:address,
    _gauge:address,
    _factory: address,
    _nfpm: address,
    _locker: address
  ) -> Position:
  """
  @notice Returns concentrated pool position data
  @param _id The token ID of the position
  @param _account The account to fetch positions for
  @param _pool The pool address
  @param _gauge The pool gauge address
  @param _factory The CL factory address
  @param _nfpm The NFPM address
  @param _locker The locker contract address
  @return A Position struct
  """
  pos: Position = empty(Position)

  account: address = _account
  if _locker != empty(address):
    account = _locker
    locker: ILocker = ILocker(_locker)
    pos.locker = _locker
    pos.unlocks_at = staticcall locker.lockedUntil()
  
  pos.id = _id
  pos.lp = _pool

  nfpm: INFPositionManager = INFPositionManager(_nfpm)

  data: PositionData = staticcall nfpm.positions(pos.id)

  # Try to find the pool if we're fetching an unstaked position
  if pos.lp == empty(address):
    pos.lp = staticcall lp_shared.IPoolFactory(_factory).getPool(
      data.token0,
      data.token1,
      convert(data.tickSpacing, int24)
    )

  if pos.lp == empty(address):
    return empty(Position)

  pool: IPool = IPool(pos.lp)
  gauge: ICLGauge = ICLGauge(_gauge)
  slot: Slot = staticcall pool.slot0()
  staked: bool = False

  # Try to find the gauge if we're fetching an unstaked position
  if _gauge == empty(address):
    gauge = ICLGauge(staticcall lp_shared.voter.gauges(pos.lp))

  amounts: Amounts = staticcall self.cl_helper.principal(
    nfpm.address, pos.id, slot.sqrtPriceX96
  )
  pos.amount0 = amounts.amount0
  pos.amount1 = amounts.amount1

  pos.liquidity = convert(data.liquidity, uint256)
  pos.tick_lower = data.tickLower
  pos.tick_upper = data.tickUpper

  pos.sqrt_ratio_lower = staticcall self.cl_helper.getSqrtRatioAtTick(pos.tick_lower)
  pos.sqrt_ratio_upper = staticcall self.cl_helper.getSqrtRatioAtTick(pos.tick_upper)

  amounts_fees: Amounts = staticcall self.cl_helper.fees(nfpm.address, pos.id)
  pos.unstaked_earned0 = amounts_fees.amount0
  pos.unstaked_earned1 = amounts_fees.amount1

  if gauge.address != empty(address):
    staked = staticcall gauge.stakedContains(account, pos.id)

  if staked:
    pos.emissions_earned = staticcall gauge.earned(account, pos.id) \
      + staticcall gauge.rewards(pos.id)

  # Reverse the liquidity since a staked position uses full available liquidity
  if staked:
    pos.staked = pos.liquidity
    pos.staked0 = pos.amount0
    pos.staked1 = pos.amount1
    pos.amount0 = 0
    pos.amount1 = 0
    pos.liquidity = 0

  return pos

@internal
@view
def _v2_position(_account: address, _pool: address, _locker: address) -> Position:
  """
  @notice Returns v2 pool position data
  @param _account The account to fetch positions for
  @param _pool The pool address
  @param _locker The locker contract address
  @return A Position struct
  """
  pool: IPool = IPool(_pool)
  gauge: IGauge = IGauge(staticcall lp_shared.voter.gauges(_pool))
  decimals: uint8 = staticcall pool.decimals()

  pos: Position = empty(Position)

  account: address = _account
  if _locker != empty(address):
    account = _locker
    locker: ILocker = ILocker(_locker)
    pos.locker = _locker
    pos.unlocks_at = staticcall locker.lockedUntil()
  
  pos.lp = pool.address
  pos.liquidity = staticcall pool.balanceOf(account)
  pos.unstaked_earned0 = staticcall pool.claimable0(account)
  pos.unstaked_earned1 = staticcall pool.claimable1(account)
  claimable_delta0: uint256 = staticcall pool.index0() - staticcall pool.supplyIndex0(account)
  claimable_delta1: uint256 = staticcall pool.index1() - staticcall pool.supplyIndex1(account)

  if claimable_delta0 > 0:
    pos.unstaked_earned0 += \
      (pos.liquidity * claimable_delta0) // 10**convert(decimals, uint256)
  if claimable_delta1 > 0:
    pos.unstaked_earned1 += \
      (pos.liquidity * claimable_delta1) // 10**convert(decimals, uint256)

  if gauge.address != empty(address):
    pos.staked = staticcall gauge.balanceOf(account)
    pos.emissions_earned = staticcall gauge.earned(account)

  if pos.liquidity + pos.staked + pos.emissions_earned + pos.unstaked_earned0 == 0:
    return empty(Position)

  pool_liquidity: uint256 = staticcall pool.totalSupply()
  reserve0: uint256 = staticcall pool.reserve0()
  reserve1: uint256 = staticcall pool.reserve1()

  pos.amount0 = (pos.liquidity * reserve0) // pool_liquidity
  pos.amount1 = (pos.liquidity * reserve1) // pool_liquidity
  pos.staked0 = (pos.staked * reserve0) // pool_liquidity
  pos.staked1 = (pos.staked * reserve1) // pool_liquidity

  return pos

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
  locker_factory: ILockerFactory = ILockerFactory(staticcall self.cl_launcher.lockerFactory())

  gauge_alive: bool = staticcall lp_shared.voter.isAlive(gauge.address)
  fee_voting_reward: address = empty(address)
  emissions: uint256 = 0
  emissions_token: address = empty(address)
  staked0: uint256 = 0
  staked1: uint256 = 0
  tick_spacing: int24 = staticcall pool.tickSpacing()
  pool_liquidity: uint128 = staticcall pool.liquidity()
  gauge_liquidity: uint128 = staticcall pool.stakedLiquidity()
  token0_fees: uint256 = 0
  token1_fees: uint256 = 0
  locked: uint256 = staticcall locker_factory.locked(_data[1])
  emerging: uint256 = staticcall self.cl_launcher.emerging(_data[1])
  created_at: uint32 = 0

  slot: Slot = staticcall pool.slot0()
  tick_low: int24 = (slot.tick // tick_spacing) * tick_spacing
  tick_high: int24 = tick_low + tick_spacing

  if gauge.address == empty(address):
    launcher_pool: PoolLauncherPool = staticcall self.cl_launcher.pools(_data[1])

    if launcher_pool.createdAt != 0:
      created_at = launcher_pool.createdAt
      
      # fetch new and old observations from pool oracle
      obs_new: Observation = staticcall pool.observations(convert(slot.observationIndex, uint256))
      obs_old: Observation = staticcall pool.observations(0)

      if slot.cardinality >= slot.cardinalityNext:
        old_index: uint256 = convert(((slot.observationIndex + 1) % slot.cardinality), uint256)
        obs_old = staticcall pool.observations(old_index)

      # compute time delta and seconds per liquidity delta
      time_delta: uint256 = convert((obs_new.blockTimestamp - obs_old.blockTimestamp), uint256)
      splc_delta: uint256 = convert((obs_new.secondsPerLiquidityCumulativeX128 - obs_old.secondsPerLiquidityCumulativeX128), uint256)

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
  if self.alm_factory != empty(IAlmFactory):
    alm_wrapper = self._alm_pool_to_wrapper(pool.address)
    

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
    bribe=lp_shared._voter_gauge_to_incentive(gauge.address),
    factory=_data[0],

    emissions=emissions,
    emissions_token=emissions_token,

    pool_fee=convert(staticcall pool.fee(), uint256),
    unstaked_fee=convert(staticcall pool.unstakedFee(), uint256),
    token0_fees=token0_fees,
    token1_fees=token1_fees,
    locked=locked,
    emerging=emerging,
    created_at=created_at,

    nfpm=_data[3],
    alm=alm_wrapper,

    root=lp_shared._root_lp_address(_data[0], _token0, _token1, tick_spacing),
  )

@internal
@view
def _has_userPositions(_nfpm: address) -> bool:
  """
  @notice Checks for `userPositions()` support, missing for pre-Superchain NFPM
  @param _nfpm The NFPM address
  @return Returns True if supported
  """
  response: Bytes[32] = b""
  response = raw_call(
      _nfpm,
      abi_encode(
        # We just need valid addresses, please ignore the values
        _nfpm, _nfpm, method_id=method_id("userPositions(address,address)"),
      ),
      max_outsize=32,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[1]

  return len(response) > 0

@internal
@view
def _alm_pool_to_wrapper(_pool: address) -> address:
  """
  @notice Returns the ALM wrapper for the given pool
  @param _pool The pool to return the wrapper for
  """
  mapped_wrapper: address = self.alm_map[chain.id][_pool]
  if mapped_wrapper != empty(address):
    return mapped_wrapper
  return staticcall self.alm_factory.poolToWrapper(_pool)


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
