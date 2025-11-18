# SPDX-License-Identifier: BUSL-1.1
# @version ^0.4.0

# @title Velodrome Finance Position Sugar
# @author stas, ethzoomer
# @notice Makes it nicer to work with liquidity positions.

# Structs

MAX_POSITIONS: public(constant(uint256)) = 200
MAX_FACTORIES: public(constant(uint256)) = 10
MAX_ITERATIONS: public(constant(uint256)) = 30000

# Slot0 from CLPool.sol
struct Slot:
  sqrtPriceX96: uint160
  tick: int24
  observationIndex: uint16
  cardinality: uint16
  cardinalityNext: uint16
  unlocked: bool

struct Amounts:
  amount0: uint256
  amount1: uint256

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
  def slot0() -> Slot: view # CL slot data
  def factory() -> address: view # CL factory address

interface IGauge:
  def earned(_account: address) -> uint256: view
  def balanceOf(_account: address) -> uint256: view
  def totalSupply() -> uint256: view

interface ICLGauge:
  def earned(_account: address, _position_id: uint256) -> uint256: view
  def rewards(_position_id: uint256) -> uint256: view
  def stakedContains(_account: address, _position_id: uint256) -> bool: view
  def stakedValues(_account: address) -> DynArray[uint256, MAX_POSITIONS]: view
  def gaugeFactory() -> address: view

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

interface ILockerFactory:
  def lockersPerPoolPerUser(_pool: address, _user: address) -> DynArray[address, MAX_POSITIONS]: view
  def lockers(_pool: address, _start: uint256, _end: uint256) -> DynArray[address, MAX_POSITIONS]: view

interface ILocker:
  def lockedUntil() -> uint32: view
  def lp() -> uint256: view

interface ILpHelper:
  def is_root_placeholder_factory(_factory: address) -> bool: view
  def fetch_nfpm(_factory: address) -> address: view

interface IFactoryRegistry:
  def poolFactories() -> DynArray[address, MAX_FACTORIES]: view

interface IVoter:
  def gauges(_pool_addr: address) -> address: view

interface IPoolFactory:
  def allPoolsLength() -> uint256: view
  def allPools(_index: uint256) -> address: view
  def getPool(_token0: address, _token1: address, _fee: int24) -> address: view

# Vars
voter: public(IVoter)
registry: public(IFactoryRegistry)
convertor: public(address)
cl_helper: public(ISlipstreamHelper)
alm_factory: public(IAlmFactory)
alm_map: public(HashMap[uint256, HashMap[address, address]])
v2_launcher: public(IPoolLauncher)
cl_launcher: public(IPoolLauncher)
lp_helper: public(ILpHelper)
v2_locker_factory: public(ILockerFactory)
cl_locker_factory: public(ILockerFactory)

# Methods

@deploy
def __init__(_voter: address, _registry: address, _convertor: address, _slipstream_helper: address,\
    _alm_factory: address, _v2_launcher: address, _cl_launcher: address, _lp_helper: address):
  """
  @dev Sets up our external contract addresses
  """
  self.voter = IVoter(_voter)
  self.registry = IFactoryRegistry(_registry)
  self.convertor = _convertor
  self.cl_helper = ISlipstreamHelper(_slipstream_helper)
  self.alm_factory = IAlmFactory(_alm_factory)
  self.alm_map[57073][0xaC7fC3e9b9d3377a90650fe62B858fF56bD841C9] = 0xFcD4bE2aDb8cdB01e5308Cd96ba06F5b92aebBa1
  self.v2_launcher = IPoolLauncher(_v2_launcher)
  self.cl_launcher = IPoolLauncher(_cl_launcher)
  self.lp_helper = ILpHelper(_lp_helper)
  if _v2_launcher != empty(address) and _cl_launcher != empty(address):
    self.v2_locker_factory = ILockerFactory(staticcall self.v2_launcher.lockerFactory())
    self.cl_locker_factory = ILockerFactory(staticcall self.cl_launcher.lockerFactory())

@external
@view
def positions(_limit: uint256, _offset: uint256, _account: address)\
    -> DynArray[Position, MAX_POSITIONS]:
  """
  @notice Returns a collection of positions
  @param _account The account to fetch positions for
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip (for optimization)
  @return Array for Position structs
  """
  factories: DynArray[address, MAX_FACTORIES] = staticcall self.registry.poolFactories()

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
  @return Array for Position structs
  """
  return self._positions(_limit, _offset, _account, [_factory])

@internal
@view
def _positions(
  _limit: uint256,
  _offset: uint256,
  _account: address,
  _factories: DynArray[address, MAX_FACTORIES]
) -> DynArray[Position, MAX_POSITIONS]:
  """
  @notice Returns a collection of positions for a set of factories
  @param _account The account to fetch positions for
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip (for optimization)
  @param _factories The factories to fetch from
  @return Array for Position structs
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

  for index: uint256 in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: IPoolFactory = IPoolFactory(_factories[index])

    if staticcall self.lp_helper.is_root_placeholder_factory(factory.address):
      continue

    pools_count: uint256 = staticcall factory.allPoolsLength()

    nfpm: INFPositionManager = \
      INFPositionManager(staticcall self.lp_helper.fetch_nfpm(factory.address))

    # V2/Basic pool
    if nfpm.address == empty(address):
      for pindex: uint256 in range(0, MAX_ITERATIONS):
        if pindex >= pools_count or pools_done >= _limit:
          break

        # Basically skip calls for offset records...
        if to_skip > 0:
          to_skip -= 1
          continue
        else:
          pools_done += 1

        pool_addr: address = staticcall factory.allPools(pindex)

        if pool_addr == self.convertor:
          continue

        pos: Position = self._v2_position(_account, pool_addr, empty(address))

        if pos.lp != empty(address):
          if len(positions) < MAX_POSITIONS:
            positions.append(pos)
          else:
            break

        # Fetch locked V2/Basic positions
        if self.v2_launcher.address != empty(address):
          lockers: DynArray[address, MAX_POSITIONS] = staticcall self.v2_locker_factory.lockersPerPoolPerUser(pool_addr, _account)

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
      for pindex: uint256 in range(0, MAX_ITERATIONS):
        if pindex >= pools_count or pools_done >= _limit:
          break

        # Basically skip calls for offset records...
        if to_skip > 0:
          to_skip -= 1
          continue
        else:
          pools_done += 1

        pool_addr: address = staticcall factory.allPools(pindex)
        gauge: ICLGauge = ICLGauge(staticcall self.voter.gauges(pool_addr))
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
        if self.cl_launcher.address != empty(address):
          lockers: DynArray[address, MAX_POSITIONS] = staticcall self.cl_locker_factory.lockersPerPoolPerUser(pool_addr, _account)

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

  factories: DynArray[address, MAX_FACTORIES] = \
    staticcall self.registry.poolFactories()

  to_skip: uint256 = _offset
  positions_done: uint256 = 0
  factories_count: uint256 = len(factories)

  for index: uint256 in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: IPoolFactory = IPoolFactory(factories[index])

    nfpm: INFPositionManager = \
      INFPositionManager(staticcall self.lp_helper.fetch_nfpm(factory.address))

    if nfpm.address == empty(address):
      continue

    if staticcall self.lp_helper.is_root_placeholder_factory(factory.address):
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
    pos.lp = staticcall IPoolFactory(_factory).getPool(
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
    gauge = ICLGauge(staticcall self.voter.gauges(pos.lp))

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
  gauge: IGauge = IGauge(staticcall self.voter.gauges(_pool))
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
def _alm_pool_to_wrapper(_pool: address) -> address:
  """
  @notice Returns the ALM wrapper for the given pool
  @param _pool The pool to return the wrapper for
  """
  mapped_wrapper: address = self.alm_map[chain.id][_pool]
  if mapped_wrapper != empty(address):
    return mapped_wrapper
  return staticcall self.alm_factory.poolToWrapper(_pool)

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
