# SPDX-License-Identifier: BUSL-1.1
# @version >=0.3.6 <0.4.0

# @title Velodrome Finance CLAMM Sugar
# @author stas, ZoomerAnon
# @notice Makes it nicer to work with Slipstream CL pools.

# Structs

MAX_POOLS: constant(uint256) = 1000
MAX_POSITIONS: constant(uint256) = 100

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

struct UserPosition:
  token_id: uint256
  staked: bool
  tick_lower: int24
  tick_upper: int24
  liquidity: uint128
  unstaked_earned0: uint128
  unstaked_earned1: uint128
  emissions_earned: uint256

struct Lp:
  lp: address
  nft: address
  tick: int24
  price: uint160

  token0: address
  reserve0: uint256

  token1: address
  reserve1: uint256

  gauge: address
  gauge_alive: bool

  fee: address
  factory: address

  emissions: uint256
  emissions_token: address

  staked_fee: uint24
  unstaked_fee: uint24
  token0_fees: uint128
  token1_fees: uint128

  positions: DynArray[UserPosition, MAX_POSITIONS]

# TODO: epoch data/voting rewards

# Our contracts / Interfaces

interface IERC20:
  def decimals() -> uint8: view
  def symbol() -> String[100]: view
  def balanceOf(_account: address) -> uint256: view

# (These functions don't yet exist on the CL pool factory)
interface IPoolFactory:
  def allPoolsLength() -> uint256: view
  def allPools(_index: uint256) -> address: view

interface IV3Pool:
  def token0() -> address: view
  def token1() -> address: view
  def gauge() -> address: view
  def nft() -> address: view
  def tickSpacing() -> int24: view
  def slot0() -> Slot: view
  def gaugeFees() -> GaugeFees: view
  def fee() -> uint24: view
  def unstakedFee() -> uint24: view

interface IVoter:
  def gauges(_pool_addr: address) -> address: view
  def gaugeToBribe(_gauge_addr: address) -> address: view
  def gaugeToFees(_gauge_addr: address) -> address: view
  def isAlive(_gauge_addr: address) -> bool: view
  def isWhitelistedToken(_token_addr: address) -> bool: view
  def v1Factory() -> address: view

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

# Vars
factory: public(IPoolFactory)
voter: public(IVoter)

# Methods

@external
def __init__(_voter: address, _factory: address):
  """
  @dev Sets up our external contract addresses
  """
  self.voter = IVoter(_voter)
  self.factory = IPoolFactory(_factory)

@internal
@view
def _pools() -> DynArray[address[3], MAX_POOLS]:
  """
  @notice Returns a compiled list of pool and its factory and gauge
  @return Array of three addresses (factory, pool, gauge)
  """

  pools: DynArray[address[3], MAX_POOLS] = \
    empty(DynArray[address[3], MAX_POOLS])

  pools_count: uint256 = self.factory.allPoolsLength()

  for pindex in range(0, MAX_POOLS):
    if pindex >= pools_count:
      break

    pool_addr: address = self.factory.allPools(pindex)

    gauge_addr: address = self.voter.gauges(pool_addr)

    pools.append([self.factory.address, pool_addr, gauge_addr])

  return pools

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
  pools: DynArray[address[3], MAX_POOLS] = self._pools()

  return self._byData(pools[_index], _account)

@internal
@view
def _byData(_data: address[3], _account: address) -> Lp:
  """
  @notice Returns pool data based on the factory, pool and gauge addresses
  @param _data The addresses to lookup
  @param _account The user account
  @return Lp struct
  """
  pool: IV3Pool = IV3Pool(_data[1])
  gauge: ICLGauge = ICLGauge(_data[2])
  nft: INFTPositionManager = INFTPositionManager(pool.nft())

  gauge_fees: GaugeFees = pool.gaugeFees()
  gauge_alive: bool = self.voter.isAlive(gauge.address)
  fee_voting_reward: address = empty(address)
  emissions: uint256 = 0
  emissions_token: address = empty(address)
  token0: IERC20 = IERC20(pool.token0())
  token1: IERC20 = IERC20(pool.token1())

  if gauge.address != empty(address):
    fee_voting_reward = gauge.feesVotingReward()
    emissions_token = gauge.rewardToken()

  if gauge_alive:
    emissions = gauge.rewardRate()

  slot: Slot = pool.slot0()
  # https://blog.uniswap.org/uniswap-v3-math-primer
  sqrt_price: uint160 = slot.sqrt_price / (2**96)
  # Do we want to normalize for token decimals here?
  price: uint160 = sqrt_price**2

  positions: DynArray[UserPosition, MAX_POSITIONS] = empty(DynArray[UserPosition, MAX_POSITIONS])
  
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
      UserPosition({
        token_id: position_id,
        staked: staked,
        tick_lower: position_data.tick_lower,
        tick_upper: position_data.tick_upper,
        liquidity: position_data.liquidity,
        unstaked_earned0: position_data.unstaked_earned0,
        unstaked_earned1: position_data.unstaked_earned1,
        emissions_earned: emissions_earned
      })
    )

  return Lp({
    lp: pool.address,
    nft: nft.address,

    tick: pool.tickSpacing(),
    price: price,

    token0: token0.address,
    reserve0: token0.balanceOf(pool.address),

    token1: token1.address,
    reserve1: token1.balanceOf(pool.address),

    gauge: gauge.address,
    gauge_alive: gauge_alive,

    fee: fee_voting_reward,
    factory: _data[0],

    emissions: emissions,
    emissions_token: emissions_token,

    staked_fee: pool.fee(),
    unstaked_fee: pool.unstakedFee(),
    token0_fees: gauge_fees.token0,
    token1_fees: gauge_fees.token1,

    positions: positions
  })
