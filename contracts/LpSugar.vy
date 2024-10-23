# SPDX-License-Identifier: BUSL-1.1
# pragma version ~=0.4.0

# @title Velodrome Finance LP Sugar v3
# @author stas, ethzoomer
# @notice Makes it nicer to work with the liquidity pools.

from contracts import LpSugarModule as helper

# Vars
voter: public(helper.IVoter) # Voter on root , LeafVoter on leaf chain
registry: public(helper.IFactoryRegistry)
convertor: public(address)
cl_helper: public(helper.ISlipstreamHelper)
alm_factory: public(helper.IAlmFactory)
canonical_chains: public(HashMap[uint256, bool])

# Methods

@deploy
def __init__(_voter: address, _registry: address,\
    _convertor: address, _slipstream_helper: address, _alm_factory: address):
  """
  @dev Sets up our external contract addresses
  """
  self.voter = helper.IVoter(_voter)
  self.registry = helper.IFactoryRegistry(_registry)
  self.convertor = _convertor
  self.cl_helper = helper.ISlipstreamHelper(_slipstream_helper)
  self.alm_factory = helper.IAlmFactory(_alm_factory)
  self.canonical_chains[10] = True
  self.canonical_chains[8453] = True

@external
@view
def forSwaps(_limit: uint256, _offset: uint256) -> DynArray[helper.SwapLp, helper.MAX_POOLS]:
  """
  @notice Returns a compiled list of pools for swaps from pool factories (sans v1)
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip
  @return `SwapLp` structs
  """
  factories: DynArray[address, helper.MAX_FACTORIES] = staticcall self.registry.poolFactories()
  factories_count: uint256 = len(factories)

  pools: DynArray[helper.SwapLp, helper.MAX_POOLS] = empty(DynArray[helper.SwapLp, helper.MAX_POOLS])
  to_skip: uint256 = _offset
  left: uint256 = _limit

  for index: uint256 in range(0, helper.MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: helper.IPoolFactory = helper.IPoolFactory(factories[index])
    if helper._is_root_factory(factory.address):
      continue

    nfpm: address = helper._fetch_nfpm(factory.address, self.registry)
    pools_count: uint256 = staticcall factory.allPoolsLength()

    for pindex: uint256 in range(0, helper.MAX_ITERATIONS):
      if pindex >= pools_count or len(pools) >= helper.MAX_POOLS:
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
      pool: helper.IPool = helper.IPool(pool_addr)
      type: int24 = -1
      token0: address = staticcall pool.token0()
      token1: address = staticcall pool.token1()
      reserve0: uint256 = 0
      pool_fee: uint256 = 0

      if nfpm != empty(address):
        type = staticcall pool.tickSpacing()
        reserve0 = helper._safe_balance_of(token0, pool_addr)
        pool_fee = convert(staticcall pool.fee(), uint256)
      else:
        if staticcall pool.stable():
          type = 0
        reserve0 = staticcall pool.reserve0()
        pool_fee = staticcall factory.getFee(pool_addr, (type == 0))

      if reserve0 > 0 or pool_addr == self.convertor:
        pools.append(helper.SwapLp(
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
    _addresses: DynArray[address, helper.MAX_TOKENS]) -> DynArray[helper.Token, helper.MAX_TOKENS]:
  """
  @notice Returns a collection of tokens data based on available pools
  @param _limit The max amount of tokens to return
  @param _offset The amount of pools to skip
  @param _account The account to check the balances
  @return Array for Token structs
  """
  pools: DynArray[address[4], helper.MAX_POOLS] = helper._pools(_limit, _offset,\
    staticcall self.registry.poolFactories(), self.convertor, self.voter, self.registry)

  pools_count: uint256 = len(pools)
  addresses_count: uint256 = len(_addresses)
  col: DynArray[helper.Token, helper.MAX_TOKENS] = empty(DynArray[helper.Token, helper.MAX_TOKENS])
  seen: DynArray[address, helper.MAX_TOKENS] = empty(DynArray[address, helper.MAX_TOKENS])

  for index: uint256 in range(0, helper.MAX_TOKENS):
    if len(col) >= _limit or index >= addresses_count:
      break

    col.append(helper._token(_addresses[index], _account, self.voter))
    seen.append(_addresses[index])

  for index: uint256 in range(0, helper.MAX_POOLS):
    if len(col) >= _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]

    pool: helper.IPool = helper.IPool(pool_data[1])
    token0: address = staticcall pool.token0()
    token1: address = staticcall pool.token1()

    if token0 not in seen:
      col.append(helper._token(token0, _account, self.voter))
      seen.append(token0)

    if token1 not in seen:
      col.append(helper._token(token1, _account, self.voter))
      seen.append(token1)

  return col

@external
@view
def all(_limit: uint256, _offset: uint256) -> DynArray[helper.Lp, helper.MAX_LPS]:
  """
  @notice Returns a collection of pool data
  @param _limit The max amount of pools to return
  @param _offset The amount of pools to skip
  @return Array for Lp structs
  """
  col: DynArray[helper.Lp, helper.MAX_LPS] = empty(DynArray[helper.Lp, helper.MAX_LPS])
  pools: DynArray[address[4], helper.MAX_POOLS] = helper._pools(_limit, _offset,\
    staticcall self.registry.poolFactories(), self.convertor, self.voter, self.registry)
  pools_count: uint256 = len(pools)

  for index: uint256 in range(0, helper.MAX_POOLS):
    if len(col) == _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]
    pool: helper.IPool = helper.IPool(pool_data[1])
    token0: address = staticcall pool.token0()
    token1: address = staticcall pool.token1()

    # If this is a CL factory/NFPM present...
    if pool_data[3] != empty(address):
      col.append(helper._cl_lp(pool_data, token0, token1, self.voter, self.cl_helper,\
        self.alm_factory))
    else:
      col.append(helper._v2_lp(pool_data, token0, token1, self.voter))

  return col

@external
@view
def byIndex(_index: uint256) -> helper.Lp:
  """
  @notice Returns pool data at a specific stored index
  @param _index The index to lookup
  @return Lp struct
  """
  # Basically index is the limit and the offset is always one...
  # This will fire if _index is out of bounds
  pool_data: address[4] = helper._pools(1, _index,\
    staticcall self.registry.poolFactories(), self.convertor, self.voter, self.registry)[0]
  pool: helper.IPool = helper.IPool(pool_data[1])
  token0: address = staticcall pool.token0()
  token1: address = staticcall pool.token1()

  # If this is a CL factory/NFPM present...
  if pool_data[3] != empty(address):
    return helper._cl_lp(pool_data, token0, token1, self.voter, self.cl_helper, self.alm_factory)

  return helper._v2_lp(pool_data, token0, token1, self.voter)

@external
@view
def positions(_limit: uint256, _offset: uint256, _account: address)\
    -> DynArray[helper.Position, helper.MAX_POSITIONS]:
  """
  @notice Returns a collection of positions
  @param _account The account to fetch positions for
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip (for optimization)
  @return Array for Lp structs
  """
  factories: DynArray[address, helper.MAX_FACTORIES] = staticcall self.registry.poolFactories()
  is_canonical: bool = self.canonical_chains[chain.id]

  return helper._positions(_limit, _offset, _account, factories,\
    self.alm_factory, self.convertor, self.registry, self.voter, is_canonical, self.cl_helper)

@external
@view
def positionsByFactory(
    _limit: uint256,
    _offset: uint256,
    _account: address,
    _factory: address
) -> DynArray[helper.Position, helper.MAX_POSITIONS]:
  """
  @notice Returns a collection of positions for the given factory
  @param _account The account to fetch positions for
  @param _limit The max amount of pools to process
  @param _offset The amount of pools to skip (for optimization)
  @param _factory The INFPositionManager address used to fetch positions
  @return Array for Lp structs
  """
  return helper._positions(_limit, _offset, _account, [_factory], self.alm_factory, self.convertor,\
    self.registry, self.voter, self.canonical_chains[chain.id], self.cl_helper)

@external
@view
def unstakedPositions(
    _limit: uint256,
    _offset: uint256,
    _account: address
) -> DynArray[helper.Position, helper.MAX_POSITIONS]:
  """
  @notice Returns a collection of unstaked CL positions for canonical chains
  @param _account The account to fetch positions for
  @param _limit The max amount of positions to process
  @param _offset The amount of positions to skip (for optimization)
  @return Array for Lp structs
  """
  positions: DynArray[helper.Position, helper.MAX_POSITIONS] = \
    empty(DynArray[helper.Position, helper.MAX_POSITIONS])

  if not self.canonical_chains[chain.id] or _account == empty(address):
    return positions

  to_skip: uint256 = _offset
  positions_done: uint256 = 0

  factories: DynArray[address, helper.MAX_FACTORIES] = staticcall self.registry.poolFactories()
  factories_count: uint256 = len(factories)

  for index: uint256 in range(0, helper.MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: helper.IPoolFactory = helper.IPoolFactory(factories[index])

    nfpm: helper.INFPositionManager = \
      helper.INFPositionManager(helper._fetch_nfpm(factory.address, self.registry))

    if nfpm.address == empty(address) or helper._is_root_factory(factory.address):
      continue

    # Fetch unstaked CL positions.
    # Since we can't iterate over pools on non leaf, offset and limit don't apply here.
    positions_count: uint256 = staticcall nfpm.balanceOf(_account)

    for pindex: uint256 in range(0, helper.MAX_POSITIONS):
      if pindex >= positions_count or positions_done >= _limit:
        break

      # Basically skip calls for offset records...
      if to_skip > 0:
        to_skip -= 1
        continue
      else:
        positions_done += 1

      pos_id: uint256 = staticcall nfpm.tokenOfOwnerByIndex(_account, pindex)
      pos: helper.Position = helper._cl_position(
        pos_id,
        _account,
        empty(address),
        empty(address),
        factory.address,
        nfpm.address,
        self.voter,
        self.cl_helper
      )

      if pos.lp != empty(address):
        if len(positions) < helper.MAX_POSITIONS:
          positions.append(pos)
        else:
          break

  return positions

@external
@view
def epochsLatest(_limit: uint256, _offset: uint256) \
    -> DynArray[helper.LpEpoch, helper.MAX_POOLS]:
  """
  @notice Returns all pools latest epoch data (up to 200 items)
  @param _limit The max amount of pools to check for epochs
  @param _offset The amount of pools to skip
  @return Array for LpEpoch structs
  """
  pools: DynArray[address[4], helper.MAX_POOLS] = helper._pools(_limit, _offset,\
    staticcall self.registry.poolFactories(), self.convertor, self.voter, self.registry)
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[helper.LpEpoch, helper.MAX_POOLS] = empty(DynArray[helper.LpEpoch, helper.MAX_POOLS])

  for index: uint256 in range(0, helper.MAX_ITERATIONS):
    if counted == _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]

    if staticcall self.voter.isAlive(pool_data[2]) == False:
      continue

    col.append(helper._epochLatestByAddress(pool_data[1], pool_data[2], self.voter))

    counted += 1

  return col

@external
@view
def epochsByAddress(_limit: uint256, _offset: uint256, _address: address) \
    -> DynArray[helper.LpEpoch, helper.MAX_EPOCHS]:
  """
  @notice Returns all pool epoch data based on the address
  @param _limit The max amount of epochs to return
  @param _offset The number of epochs to skip
  @param _address The address to lookup
  @return Array for LpEpoch structs
  """
  return helper._epochsByAddress(_limit, _offset, _address, self.voter)

@external
@view
def rewards(_limit: uint256, _offset: uint256, _venft_id: uint256) \
    -> DynArray[helper.Reward, helper.MAX_POOLS]:
  """
  @notice Returns a collection of veNFT rewards data
  @param _limit The max amount of pools to check for rewards
  @param _offset The amount of pools to skip checking for rewards
  @param _venft_id The veNFT ID to get rewards for
  @return Array for VeNFT Reward structs
  """
  pools: DynArray[address[4], helper.MAX_POOLS] = helper._pools(_limit, _offset,\
    staticcall self.registry.poolFactories(), self.convertor, self.voter, self.registry)
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[helper.Reward, helper.MAX_POOLS] = empty(DynArray[helper.Reward, helper.MAX_POOLS])

  for pindex: uint256 in range(0, helper.MAX_POOLS):
    if counted == _limit or pindex >= pools_count:
      break

    pool_data: address[4] = pools[pindex]
    pcol: DynArray[helper.Reward, helper.MAX_POOLS] = \
      helper._poolRewards(_venft_id, pool_data[1], pool_data[2], self.voter)

    # Basically merge pool rewards to the rest of the rewards...
    for cindex: uint256 in range(helper.MAX_POOLS):
      if cindex >= len(pcol):
        break

      col.append(pcol[cindex])

    counted += 1

  return col

@external
@view
def rewardsByAddress(_venft_id: uint256, _pool: address) \
    -> DynArray[helper.Reward, helper.MAX_POOLS]:
  """
  @notice Returns a collection of veNFT rewards data for a specific pool
  @param _venft_id The veNFT ID to get rewards for
  @param _pool The pool address to get rewards for
  @return Array for VeNFT Reward structs
  """
  gauge_addr: address = staticcall self.voter.gauges(_pool)

  return helper._poolRewards(_venft_id, _pool, gauge_addr, self.voter)
