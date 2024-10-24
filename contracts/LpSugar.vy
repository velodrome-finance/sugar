# SPDX-License-Identifier: BUSL-1.1
# pragma version ~=0.4.0

# @title Velodrome Finance LP Sugar v3
# @author stas, ethzoomer
# @notice Makes it nicer to work with the liquidity pools.

# Structs

MAX_FACTORIES: public(constant(uint256)) = 10
MAX_POOLS: public(constant(uint256)) = 2000
MAX_ITERATIONS: public(constant(uint256)) = 8000
MAX_TOKENS: public(constant(uint256)) = 2000
MAX_LPS: public(constant(uint256)) = 500
MAX_EPOCHS: public(constant(uint256)) = 200
MAX_REWARDS: public(constant(uint256)) = 50
MAX_POSITIONS: public(constant(uint256)) = 200
WEEK: public(constant(uint256)) = 7 * 24 * 60 * 60

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
  alm: address

struct Token:
  token_address: address
  symbol: String[100]
  decimals: uint8
  account_balance: uint256
  listed: bool

struct SwapLp:
  lp: address
  type: int24 # tick spacing on CL, 0/-1 for stable/volatile on v2
  token0: address
  token1: address
  factory: address
  pool_fee: uint256

struct Lp:
  lp: address
  symbol: String[100]
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

  nfpm: address
  alm: address

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

# See:
#   https://github.com/mellow-finance/mellow-alm-toolkit/blob/main/src/interfaces/ICore.sol#L12-L60
struct AlmManagedPositionInfo:
  slippageD9: uint32
  property: uint24
  owner: address
  pool: address
  ammPositionIds: DynArray[uint256, 10]
  # ...Params removed as we don't use those
# Our contracts / Interfaces
interface IFactoryRegistry:
  def poolFactories() -> DynArray[address, MAX_FACTORIES]: view
  def factoriesToPoolFactory(_factory: address) -> address[2]: view

interface IPoolFactory:
  def allPoolsLength() -> uint256: view
  def allPools(_index: uint256) -> address: view
  def getFee(_pool_addr: address, _stable: bool) -> uint256: view
  def getPool(_token0: address, _token1: address, _fee: int24) -> address: view

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
  def gauge() -> address: view # fetches gauge from CL pool
  def tickSpacing() -> int24: view # CL tick spacing
  def slot0() -> Slot: view # CL slot data
  def gaugeFees() -> GaugeFees: view # CL gauge fees amounts
  def fee() -> uint24: view # CL fee level
  def unstakedFee() -> uint24: view # CL unstaked fee level
  def liquidity() -> uint128: view # CL active liquidity
  def stakedLiquidity() -> uint128: view # CL active staked liquidity

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
  def userPositions(_account: address, _pool_addr: address) -> DynArray[uint256, MAX_POSITIONS]: view # leaf only

interface IReward:
  def getPriorSupplyIndex(_ts: uint256) -> uint256: view
  def supplyCheckpoints(_index: uint256) -> uint256[2]: view
  def tokenRewardsPerEpoch(_token: address, _epstart: uint256) -> uint256: view
  def rewardsListLength() -> uint256: view
  def rewards(_index: uint256) -> address: view
  def earned(_token: address, _venft_id: uint256) -> uint256: view

interface ISlipstreamHelper:
  def getAmountsForLiquidity(_ratio: uint160, _ratioA: uint160, _ratioB: uint160, _liquidity: uint128) -> Amounts: view
  def getSqrtRatioAtTick(_tick: int24) -> uint160: view
  def principal(_nfpm: address, _position_id: uint256, _ratio: uint160) -> Amounts: view
  def fees(_nfpm: address, _position_id: uint256) -> Amounts: view
  def poolFees(_pool: address, _liquidity: uint128, _current_tick: int24, _lower_tick: int24, _upper_tick: int24) -> Amounts: view

interface IAlmFactory:
  def poolToAddresses(pool: address) -> address[2]: view
  def getImmutableParams() -> address[5]: view

interface IAlmCore:
  def managedPositionAt(_id: uint256) -> AlmManagedPositionInfo: view

interface IAlmLpWrapper:
  def positionId() -> uint256: view
  def totalSupply() -> uint256: view

interface ISugarHelper:
  def pools(_limit: uint256, _offset: uint256, _factories: DynArray[address, 10])\
    -> DynArray[address[4], MAX_POOLS]: view
  def token(_address: address, _account: address) -> Token: view
  def v2Lp(_data: address[4], _token0: address, _token1: address) -> Lp: view
  def positions(
    _limit: uint256,
    _offset: uint256,
    _account: address,
    _factories: DynArray[address, MAX_FACTORIES]
  ) -> DynArray[Position, 200]: view
  def clPosition(
      _id: uint256,
      _account: address,
      _pool:address,
      _gauge:address,
      _factory: address,
      _nfpm: address
    ) -> Position: view
  def v2Position(_account: address, _pool: address) -> Position: view
  def clLp(_data: address[4], _token0: address, _token1: address) -> Lp: view
  def epochLatestByAddress(_address: address, _gauge: address) -> LpEpoch: view
  def epochsByAddress(_limit: uint256, _offset: uint256, _address: address) \
      -> DynArray[LpEpoch, MAX_EPOCHS]: view
  def poolRewards(_venft_id: uint256, _pool: address, _gauge: address) \
      -> DynArray[Reward, MAX_POOLS]: view
  def fetchNfpm(_factory: address) -> address: view
  def safeBalanceOf(_token: address, _address: address) -> uint256: view
  def isRootFactory(_factory: address) -> bool: view


# Vars
voter: public(IVoter) # Voter on root , LeafVoter on leaf chain
registry: public(IFactoryRegistry)
convertor: public(address)
cl_helper: public(ISlipstreamHelper)
alm_factory: public(IAlmFactory)
canonical_chains: public(HashMap[uint256, bool])
helper: public(ISugarHelper)

# Methods

@deploy
def __init__(_voter: address, _registry: address,\
    _convertor: address, _slipstream_helper: address, _alm_factory: address, _sugar_helper: address):
  """
  @dev Sets up our external contract addresses
  """
  self.voter = IVoter(_voter)
  self.registry = IFactoryRegistry(_registry)
  self.convertor = _convertor
  self.cl_helper = ISlipstreamHelper(_slipstream_helper)
  self.alm_factory = IAlmFactory(_alm_factory)
  self.canonical_chains[10] = True
  self.canonical_chains[8453] = True
  self.helper = ISugarHelper(_sugar_helper)

@external
@view
def forSwaps(_limit: uint256, _offset: uint256) -> DynArray[SwapLp, MAX_POOLS]:
  """
  @notice Returns a compiled list of pools for swaps from pool factories (sans v1)
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip
  @return `SwapLp` structs
  """
  factories: DynArray[address, MAX_FACTORIES] = staticcall self.registry.poolFactories()
  factories_count: uint256 = len(factories)

  pools: DynArray[SwapLp, MAX_POOLS] = empty(DynArray[SwapLp, MAX_POOLS])
  to_skip: uint256 = _offset
  left: uint256 = _limit

  for index: uint256 in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: IPoolFactory = IPoolFactory(factories[index])
    if staticcall self.helper.isRootFactory(factory.address):
      continue

    nfpm: address = staticcall self.helper.fetchNfpm(factory.address)
    pools_count: uint256 = staticcall factory.allPoolsLength()

    for pindex: uint256 in range(0, MAX_ITERATIONS):
      if pindex >= pools_count or len(pools) >= MAX_POOLS:
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
        reserve0 = staticcall self.helper.safeBalanceOf(token0, pool_addr)
        pool_fee = convert(staticcall pool.fee(), uint256)
      else:
        if staticcall pool.stable():
          type = 0
        reserve0 = staticcall pool.reserve0()
        pool_fee = staticcall factory.getFee(pool_addr, (type == 0))

      if reserve0 > 0 or pool_addr == self.convertor:
        pools.append(SwapLp(
          lp = pool_addr,
          type = type,
          token0 = token0,
          token1 = token1,
          factory = factory.address,
          pool_fee = pool_fee
        ))

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
  pools: DynArray[address[4], MAX_POOLS] = staticcall self.helper.pools(_limit, _offset,\
    staticcall self.registry.poolFactories())

  pools_count: uint256 = len(pools)
  addresses_count: uint256 = len(_addresses)
  col: DynArray[Token, MAX_TOKENS] = empty(DynArray[Token, MAX_TOKENS])
  seen: DynArray[address, MAX_TOKENS] = empty(DynArray[address, MAX_TOKENS])

  for index: uint256 in range(0, MAX_TOKENS):
    if len(col) >= _limit or index >= addresses_count:
      break

    col.append(staticcall self.helper.token(_addresses[index], _account))
    seen.append(_addresses[index])

  for index: uint256 in range(0, MAX_POOLS):
    if len(col) >= _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]

    pool: IPool = IPool(pool_data[1])
    token0: address = staticcall pool.token0()
    token1: address = staticcall pool.token1()

    if token0 not in seen:
      col.append(staticcall self.helper.token(token0, _account))
      seen.append(token0)

    if token1 not in seen:
      col.append(staticcall self.helper.token(token1, _account))
      seen.append(token1)

  return col

@external
@view
def all(_limit: uint256, _offset: uint256) -> DynArray[Lp, MAX_LPS]:
  """
  @notice Returns a collection of pool data
  @param _limit The max amount of pools to return
  @param _offset The amount of pools to skip
  @return Array for Lp structs
  """
  col: DynArray[Lp, MAX_LPS] = empty(DynArray[Lp, MAX_LPS])
  pools: DynArray[address[4], MAX_POOLS] = staticcall self.helper.pools(_limit, _offset,\
    staticcall self.registry.poolFactories())
  pools_count: uint256 = len(pools)

  for index: uint256 in range(0, MAX_POOLS):
    if len(col) == _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]
    pool: IPool = IPool(pool_data[1])
    token0: address = staticcall pool.token0()
    token1: address = staticcall pool.token1()

    # If this is a CL factory/NFPM present...
    if pool_data[3] != empty(address):
      col.append(staticcall self.helper.clLp(pool_data, token0, token1))
    else:
      col.append(staticcall self.helper.v2Lp(pool_data, token0, token1))

  return col

@external
@view
def byIndex(_index: uint256) -> Lp:
  """
  @notice Returns pool data at a specific stored index
  @param _index The index to lookup
  @return Lp struct
  """
  # Basically index is the limit and the offset is always one...
  # This will fire if _index is out of bounds
  pool_data: address[4] = (staticcall self.helper.pools(1, _index,staticcall self.registry.poolFactories()))[0]
  pool: IPool = IPool(pool_data[1])
  token0: address = staticcall pool.token0()
  token1: address = staticcall pool.token1()

  # If this is a CL factory/NFPM present...
  if pool_data[3] != empty(address):
    return staticcall self.helper.clLp(pool_data, token0, token1)

  return staticcall self.helper.v2Lp(pool_data, token0, token1)

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
  factories: DynArray[address, MAX_FACTORIES] = staticcall self.registry.poolFactories()
  is_canonical: bool = self.canonical_chains[chain.id]

  return staticcall self.helper.positions(_limit, _offset, _account, factories)

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
  return staticcall self.helper.positions(_limit, _offset, _account, [_factory])

@external
@view
def unstakedPositions(
    _limit: uint256,
    _offset: uint256,
    _account: address
) -> DynArray[Position, MAX_POSITIONS]:
  """
  @notice Returns a collection of unstaked CL positions for canonical chains
  @param _account The account to fetch positions for
  @param _limit The max amount of positions to process
  @param _offset The amount of positions to skip (for optimization)
  @return Array for Lp structs
  """
  positions: DynArray[Position, MAX_POSITIONS] = \
    empty(DynArray[Position, MAX_POSITIONS])

  if not self.canonical_chains[chain.id] or _account == empty(address):
    return positions

  to_skip: uint256 = _offset
  positions_done: uint256 = 0

  factories: DynArray[address, MAX_FACTORIES] = staticcall self.registry.poolFactories()
  factories_count: uint256 = len(factories)

  for index: uint256 in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: IPoolFactory = IPoolFactory(factories[index])

    nfpm: INFPositionManager = \
      INFPositionManager(staticcall self.helper.fetchNfpm(factory.address))

    if nfpm.address == empty(address) or staticcall self.helper.isRootFactory(factory.address):
      continue

    # Fetch unstaked CL positions.
    # Since we can't iterate over pools on non leaf, offset and limit don't apply here.
    positions_count: uint256 = staticcall nfpm.balanceOf(_account)

    for pindex: uint256 in range(0, MAX_POSITIONS):
      if pindex >= positions_count or positions_done >= _limit:
        break

      # Basically skip calls for offset records...
      if to_skip > 0:
        to_skip -= 1
        continue
      else:
        positions_done += 1

      pos_id: uint256 = staticcall nfpm.tokenOfOwnerByIndex(_account, pindex)
      pos: Position = staticcall self.helper.clPosition(
        pos_id,
        _account,
        empty(address),
        empty(address),
        factory.address,
        nfpm.address
      )

      if pos.lp != empty(address):
        if len(positions) < MAX_POSITIONS:
          positions.append(pos)
        else:
          break

  return positions

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
  pools: DynArray[address[4], MAX_POOLS] = staticcall self.helper.pools(_limit, _offset,\
    staticcall self.registry.poolFactories())
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[LpEpoch, MAX_POOLS] = empty(DynArray[LpEpoch, MAX_POOLS])

  for index: uint256 in range(0, MAX_ITERATIONS):
    if counted == _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]

    if staticcall self.voter.isAlive(pool_data[2]) == False:
      continue

    col.append(staticcall self.helper.epochLatestByAddress(pool_data[1], pool_data[2]))

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
  return staticcall self.helper.epochsByAddress(_limit, _offset, _address)

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
  pools: DynArray[address[4], MAX_POOLS] = staticcall self.helper.pools(_limit, _offset,\
    staticcall self.registry.poolFactories())
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[Reward, MAX_POOLS] = empty(DynArray[Reward, MAX_POOLS])

  for pindex: uint256 in range(0, MAX_POOLS):
    if counted == _limit or pindex >= pools_count:
      break

    pool_data: address[4] = pools[pindex]
    pcol: DynArray[Reward, MAX_POOLS] = \
      staticcall self.helper.poolRewards(_venft_id, pool_data[1], pool_data[2])

    # Basically merge pool rewards to the rest of the rewards...
    for cindex: uint256 in range(MAX_POOLS):
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
  gauge_addr: address = staticcall self.voter.gauges(_pool)

  return staticcall self.helper.poolRewards(_venft_id, _pool, gauge_addr)
