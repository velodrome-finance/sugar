# SPDX-License-Identifier: BUSL-1.1
# @version ^0.4.0

# @title Velodrome Finance LP Module
# @author Velodrome Finance

MAX_FACTORIES: constant(uint256) = 10
MAX_POOLS: constant(uint256) = 2000
MAX_ITERATIONS: constant(uint256) = 8000

FACTORY_TO_INIT_HASH: HashMap[address, bytes32]

# Interfaces

interface IFactoryRegistry:
  def fallbackPoolFactory() -> address: view
  def poolFactories() -> DynArray[address, MAX_FACTORIES]: view
  def poolFactoriesLength() -> uint256: view
  def factoriesToPoolFactory(_factory: address) -> address[2]: view

interface IVoter:
  def gauges(_pool_addr: address) -> address: view
  def gaugeToBribe(_gauge_addr: address) -> address: view
  def gaugeToFees(_gauge_addr: address) -> address: view
  def isAlive(_gauge_addr: address) -> bool: view
  def isWhitelistedToken(_token_addr: address) -> bool: view

interface IPoolFactory:
  def allPoolsLength() -> uint256: view
  def allPools(_index: uint256) -> address: view
  def getFee(_pool_addr: address, _stable: bool) -> uint256: view
  def getPool(_token0: address, _token1: address, _fee: int24) -> address: view

# Vars
voter: public(IVoter) # Voter on root , LeafVoter on leaf chain
registry: public(IFactoryRegistry)
convertor: public(address)

# Methods

@deploy
def __init__(_voter: address, _registry: address, _convertor: address):
  """
  @dev Sets up our external contract addresses
  """
  self.voter = IVoter(_voter)
  self.registry = IFactoryRegistry(_registry)
  self.convertor = _convertor

  # Root (placeholder) pool factory
  self.FACTORY_TO_INIT_HASH[0xd02D36A5e826731c0cF6Be97922DAfa516B9E4B4] = \
    0xb6ce19baf736d6d711871f9c2a3b71e32332f2230ba65b57060620d5d33997c9

@internal
@view
def _pools(_limit: uint256, _offset: uint256)\
    -> DynArray[address[4], MAX_POOLS]:
  """
  @param _limit The max amount of pools to return
  @param _offset The amount of pools to skip (for optimization)
  @notice Returns a compiled list of pool and its factory and gauge
  @return Array of four addresses (factory, pool, gauge, nfpm)
  """
  factories: DynArray[address, MAX_FACTORIES] = staticcall self.registry.poolFactories()
  factories_count: uint256 = len(factories)

  to_skip: uint256 = _offset
  visited: uint256 = 0

  pools: DynArray[address[4], MAX_POOLS] = \
    empty(DynArray[address[4], MAX_POOLS])

  for index: uint256 in range(0, MAX_FACTORIES):
    if index >= factories_count:
      break

    factory: IPoolFactory = IPoolFactory(factories[index])
    if self._is_root_placeholder_factory(factory.address):
      continue

    pools_count: uint256 = staticcall factory.allPoolsLength()
    nfpm: address = self._fetch_nfpm(factory.address)

    for pindex: uint256 in range(0, MAX_ITERATIONS):
      if pindex >= pools_count or visited >= _limit + _offset or len(pools) >= MAX_POOLS:
        break

      # Since the convertor pool, first pool on one of the factories...
      if pindex == 0 and staticcall factory.allPools(0) == self.convertor:
        continue

      visited += 1

      # Basically skip calls for offset records...
      if to_skip > 0:
        to_skip -= 1
        continue

      pool_addr: address = staticcall factory.allPools(pindex)
      gauge_addr: address = staticcall self.voter.gauges(pool_addr)

      pools.append([factory.address, pool_addr, gauge_addr, nfpm])

  return pools

@internal
@view
def _is_root_placeholder_factory(_factory: address) -> bool:
  """
  @notice Checks if the factory is for root placeholder pools
  @param _factory The factory address
  @return bool
  """
  response: Bytes[32] = raw_call(
      _factory,
      method_id("bridge()"),
      max_outsize=32,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[1]

  return len(response) > 0

@internal
@view
def _fetch_nfpm(_factory: address) -> address:
  """
  @notice Returns the factory NFPM if available. CL pools should have one!
  @param _factory The factory address
  """
  # Returns the votingRewardsFactory and the gaugeFactory
  factory_data: address[2] = staticcall self.registry.factoriesToPoolFactory(_factory)

  response: Bytes[32] = raw_call(
      factory_data[1],
      method_id("nft()"),
      max_outsize=32,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[1]

  if len(response) > 0:
    return abi_decode(response, address)

  return empty(address)

@internal
@view
def _root_lp_address(
  _factory: address,
  _token0: address,
  _token1: address,
  _type: int24
) -> address:
  """
  @notice Calculates the corresponding root (placeholder) pool address
  @param _factory The factory address
  @param _token0 The pool token0
  @param _token1 The pool token1
  @param _type The pool type
  @return address
  """
  init_hash: bytes32 = self.FACTORY_TO_INIT_HASH[_factory]

  if init_hash == empty(bytes32):
    return empty(address)


  salt: bytes32 = empty(bytes32)

  if _type < 1:
    salt = keccak256(
      concat(
        convert(chain.id, bytes32),
        convert(_token0, bytes20),
        convert(_token1, bytes20),
        convert(_type == 1, bytes1))
    )
  else:
    salt = keccak256(
      concat(
        convert(chain.id, bytes32),
        convert(_token0, bytes20),
        convert(_token1, bytes20),
        convert(_type, bytes3)
      )
    )


  data: bytes32 = keccak256(
    concat(
      0xFF,
      convert(_factory, bytes20),
      salt,
      init_hash
    )
  )

  return convert(
    convert(data, uint256) & convert(max_value(uint160), uint256),
    address
  )
