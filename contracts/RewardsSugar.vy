# SPDX-License-Identifier: BUSL-1.1
# @version ^0.4.0

# @title Velodrome Finance veNFT Rewards Sugar v1
# @author Velodrome Finance
# @notice Makes it nicer to fetch veNFTs/LPs rewards

from modules import lp_shared

initializes: lp_shared

MAX_EPOCHS: public(constant(uint256)) = 200
MAX_REWARDS: public(constant(uint256)) = 50
WEEK: public(constant(uint256)) = 7 * 24 * 60 * 60

# Interfaces
interface IGauge:
  def rewardRateByEpoch(_ts: uint256) -> uint256: view

interface IPool:
  def token0() -> address: view
  def token1() -> address: view

interface IReward:
  def getPriorSupplyIndex(_ts: uint256) -> uint256: view
  def supplyCheckpoints(_index: uint256) -> uint256[2]: view
  def tokenRewardsPerEpoch(_token: address, _epstart: uint256) -> uint256: view
  def rewardsListLength() -> uint256: view
  def rewards(_index: uint256) -> address: view
  def earned(_token: address, _venft_id: uint256) -> uint256: view

# Structs
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

# Methods

@deploy
def __init__(_voter: address, _registry: address, _convertor: address):
  # Modules...
  lp_shared.__init__(_voter, _registry, _convertor)

@external
@view
def epochsLatest(_limit: uint256, _offset: uint256) \
    -> DynArray[LpEpoch, MAX_EPOCHS]:
  """
  @notice Returns all pools latest epoch data
  @param _limit The max amount of pools to check for epochs
  @param _offset The amount of pools to skip
  @return Array for LpEpoch structs
  """
  pools: DynArray[address[4], lp_shared.MAX_POOLS] = lp_shared._pools(_limit, _offset)
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[LpEpoch, MAX_EPOCHS] = empty(DynArray[LpEpoch, MAX_EPOCHS])

  for index: uint256 in range(0, lp_shared.MAX_ITERATIONS):
    if counted == _limit or index >= pools_count:
      break

    pool_data: address[4] = pools[index]

    if staticcall lp_shared.voter.isAlive(pool_data[2]) == False:
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
  bribe: IReward = IReward(lp_shared._voter_gauge_to_incentive(gauge.address))

  epoch_start_ts: uint256 = block.timestamp // WEEK * WEEK
  epoch_end_ts: uint256 = epoch_start_ts + WEEK - 1

  bribe_supply_cp: uint256[2] = staticcall bribe.supplyCheckpoints(
    staticcall bribe.getPriorSupplyIndex(epoch_end_ts)
  )

  return LpEpoch({
    ts: epoch_start_ts,
    lp: _address,
    votes: bribe_supply_cp[1],
    emissions: staticcall gauge.rewardRateByEpoch(epoch_start_ts),
    bribes: self._epochRewards(epoch_start_ts, bribe.address),
    fees: self._epochRewards(
      epoch_start_ts, staticcall lp_shared.voter.gaugeToFees(gauge.address)
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

  gauge: IGauge = IGauge(staticcall lp_shared.voter.gauges(_address))

  if staticcall lp_shared.voter.isAlive(gauge.address) == False:
    return epochs

  bribe: IReward = IReward(lp_shared._voter_gauge_to_incentive(gauge.address))

  curr_epoch_start_ts: uint256 = block.timestamp // WEEK * WEEK

  for weeks: uint256 in range(_offset, _offset + MAX_EPOCHS, bound = MAX_EPOCHS):
    epoch_start_ts: uint256 = curr_epoch_start_ts - (weeks * WEEK)
    epoch_end_ts: uint256 = epoch_start_ts + WEEK - 1

    if len(epochs) == _limit or weeks >= MAX_EPOCHS:
      break

    bribe_supply_index: uint256 = staticcall bribe.getPriorSupplyIndex(epoch_end_ts)
    bribe_supply_cp: uint256[2] = staticcall bribe.supplyCheckpoints(bribe_supply_index)

    epochs.append(LpEpoch({
      ts: epoch_start_ts,
      lp: _address,
      votes: bribe_supply_cp[1],
      emissions: staticcall gauge.rewardRateByEpoch(epoch_start_ts),
      bribes: self._epochRewards(epoch_start_ts, bribe.address),
      fees: self._epochRewards(
        epoch_start_ts, staticcall lp_shared.voter.gaugeToFees(gauge.address)
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
  rewards_len: uint256 = staticcall reward.rewardsListLength()

  for rindex: uint256 in range(MAX_REWARDS):
    if rindex >= rewards_len:
      break

    reward_token: address = staticcall reward.rewards(rindex)
    reward_amount: uint256 = staticcall reward.tokenRewardsPerEpoch(reward_token, _ts)

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
    -> DynArray[Reward, lp_shared.MAX_POOLS]:
  """
  @notice Returns a collection of veNFT rewards data
  @param _limit The max amount of pools to check for rewards
  @param _offset The amount of pools to skip checking for rewards
  @param _venft_id The veNFT ID to get rewards for
  @return Array for VeNFT Reward structs
  """
  pools: DynArray[address[4], lp_shared.MAX_POOLS] = lp_shared._pools(_limit, _offset)
  pools_count: uint256 = len(pools)
  counted: uint256 = 0

  col: DynArray[Reward, lp_shared.MAX_POOLS] = empty(DynArray[Reward, lp_shared.MAX_POOLS])

  for pindex: uint256 in range(0, lp_shared.MAX_POOLS):
    if counted == _limit or pindex >= pools_count:
      break

    pool_data: address[4] = pools[pindex]
    pcol: DynArray[Reward, lp_shared.MAX_POOLS] = \
      self._pool_rewards(_venft_id, pool_data[1], pool_data[2])

    # Basically merge pool rewards to the rest of the rewards...
    for cindex: uint256 in range(lp_shared.MAX_POOLS):
      if cindex >= len(pcol):
        break

      col.append(pcol[cindex])

    counted += 1

  return col

@external
@view
def rewardsByAddress(_venft_id: uint256, _pool: address) \
    -> DynArray[Reward, lp_shared.MAX_POOLS]:
  """
  @notice Returns a collection of veNFT rewards data for a specific pool
  @param _venft_id The veNFT ID to get rewards for
  @param _pool The pool address to get rewards for
  @return Array for VeNFT Reward structs
  """
  gauge_addr: address = staticcall lp_shared.voter.gauges(_pool)

  return self._pool_rewards(_venft_id, _pool, gauge_addr)

@internal
@view
def _pool_rewards(_venft_id: uint256, _pool: address, _gauge: address) \
    -> DynArray[Reward, lp_shared.MAX_POOLS]:
  """
  @notice Returns a collection with veNFT pool rewards
  @param _venft_id The veNFT ID to get rewards for
  @param _pool The pool address
  @param _gauge The pool gauge address
  @param _col The array of `Reward` sturcts to update
  """
  pool: IPool = IPool(_pool)

  col: DynArray[Reward, lp_shared.MAX_POOLS] = empty(DynArray[Reward, lp_shared.MAX_POOLS])

  if _pool == empty(address) or _gauge == empty(address):
    return col

  fee: IReward = IReward(staticcall lp_shared.voter.gaugeToFees(_gauge))
  bribe: IReward = IReward(lp_shared._voter_gauge_to_incentive(_gauge))

  token0: address = staticcall pool.token0()
  token1: address = staticcall pool.token1()

  fee0_amount: uint256 = staticcall fee.earned(token0, _venft_id)
  fee1_amount: uint256 = staticcall fee.earned(token1, _venft_id)

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

  bribes_len: uint256 = staticcall bribe.rewardsListLength()

  for bindex: uint256 in range(MAX_REWARDS):
    if bindex >= bribes_len:
      break

    bribe_token: address = staticcall bribe.rewards(bindex)
    bribe_amount: uint256 = staticcall bribe.earned(bribe_token, _venft_id)

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


@external
@view
def forRoot(_root_pool: address) -> address[3]:
  """
  @notice Returns rewards addresses for the root pool
  @param _root_pool the root pool address to map to
  @return Array with the root gauge, fee and incentive addresses
  """
  if chain.id not in lp_shared.ROOT_CHAIN_IDS:
    return empty(address[3])

  gauge: address = staticcall lp_shared.voter.gauges(_root_pool)

  return [
    gauge,
    staticcall lp_shared.voter.gaugeToFees(gauge),
    staticcall lp_shared.voter.gaugeToBribe(gauge)
  ]
