# @version >=0.3.6 <0.4.0

# @title Velodrome Finance Liquidity Pairs Sugar v1
# @author stas
# @notice Makes it nicer to work with the liquidity pairs.

# Structs

MAX_PAIRS: constant(uint256) = 1000
MAX_TOKENS: constant(uint256) = 2000
MAX_EPOCHS: constant(uint256) = 200
MAX_REWARDS: constant(uint256) = 16
WEEK: constant(uint256) = 7 * 24 * 60 * 60
PRECISION: constant(uint256) = 10**18
# See: `RewardsDistributor::start_time()`
EPOCHS_STARTED_AT: constant(uint256) = 1653523200

struct Token:
  token_address: address
  symbol: String[100]
  decimals: uint8
  account_balance: uint256
  price: uint256
  price_decimals: uint8

struct Pair:
  pair_address: address
  symbol: String[100]
  decimals: uint8
  stable: bool
  total_supply: uint256

  token0: address
  token0_symbol: String[100]
  token0_decimals: uint8
  reserve0: uint256
  claimable0: uint256

  token1: address
  token1_symbol: String[100]
  token1_decimals: uint8
  reserve1: uint256
  claimable1: uint256

  gauge: address
  gauge_total_supply: uint256

  fee: address
  bribe: address
  wrapped_bribe: address

  emissions: uint256
  emissions_token: address
  emissions_token_decimals: uint8

  account_balance: uint256
  account_earned: uint256
  account_staked: uint256
  account_token0_balance: uint256
  account_token1_balance: uint256

struct PairEpochBribe:
  token: address
  decimals: uint8
  symbol: String[100]
  amount: uint256

struct PairEpoch:
  ts: uint256
  pair_address: address
  votes: uint256
  emissions: uint256
  bribes: DynArray[PairEpochBribe, MAX_REWARDS]
  fees: DynArray[PairEpochBribe, MAX_REWARDS]

# Our contracts / Interfaces

interface IERC20:
  def decimals() -> uint8: view
  def symbol() -> String[100]: view
  def balanceOf(_account: address) -> uint256: view

interface IOracle:
  def getRateWithConnectors(
    _token_with_connectors: DynArray[address, MAX_TOKENS]
  ) -> uint256: view

interface IPairFactory:
  def allPairsLength() -> uint256: view
  def allPairs(_index: uint256) -> address: view

interface IWrappedBribeFactory:
  def oldBribeToNew(_external_bribe_addr: address) -> address: view
  def voter() -> address: view

interface IPair:
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

interface IVoter:
  def _ve() -> address: view
  def factory() -> address: view
  def gauges(_pair_addr: address) -> address: view
  def external_bribes(_gauge_addr: address) -> address: view
  def internal_bribes(_gauge_addr: address) -> address: view

interface IVotingEscrow:
  def token() -> address: view

interface IGauge:
  def fees0() -> uint256: view
  def fees1() -> uint256: view
  def earned(_token: address, _account: address) -> uint256: view
  def balanceOf(_account: address) -> uint256: view
  def totalSupply() -> uint256: view
  def rewardRate(_token_addr: address) -> uint256: view
  def getPriorRewardPerToken(_token_addr: address, _ts: uint256) \
    -> uint256[2]: view
  def getPriorSupplyIndex(_ts: uint256) -> uint256: view
  def supplyCheckpoints(_index: uint256) -> uint256[2]: view

interface IBribe:
  def getPriorSupplyIndex(_ts: uint256) -> uint256: view
  def supplyCheckpoints(_index: uint256) -> uint256[2]: view
  def tokenRewardsPerEpoch(_token: address, _epstart: uint256) -> uint256: view
  def getPriorRewardPerToken(_token: address, _epstart: uint256) \
    -> uint256[2]: view
  def rewardsListLength() -> uint256: view
  def rewards(_index: uint256) -> address: view

# Vars
pair_factory: public(address)
voter: public(address)
wrapped_bribe_factory: public(address)
token: public(address)
owner: public(address)

# Methods

@external
def __init__():
  """
  @dev Sets up our contract management address
  """
  self.owner = msg.sender

@external
def setup(_voter: address, _wrapped_bribe_factory: address):
  """
  @dev Sets up our external contract addresses
  """
  assert self.owner == msg.sender, 'Not allowed!'

  voter: IVoter = IVoter(_voter)
  wrapped_bribe_factory: IWrappedBribeFactory = \
    IWrappedBribeFactory(_wrapped_bribe_factory)

  assert wrapped_bribe_factory.voter() == _voter, 'Voter mismatch!'

  self.voter = _voter
  self.pair_factory = voter.factory()
  self.token = IVotingEscrow(voter._ve()).token()
  self.wrapped_bribe_factory = _wrapped_bribe_factory

@external
@view
def tokens(
    _limit: uint256,
    _offset: uint256,
    _account: address,
    _oracle: address,
    _oracle_connectors: DynArray[address, MAX_TOKENS]
  ) -> DynArray[Token, MAX_TOKENS]:
  """
  @notice Returns a collection of tokens data based on available pairs
  @param _limit The max amount of tokens to return
  @param _offset The amount of pairs to skip
  @param _account The account to check the balances
  @return Array for Token structs
  """
  pair_factory: IPairFactory = IPairFactory(self.pair_factory)
  counted: uint256 = pair_factory.allPairsLength()

  col: DynArray[Token, MAX_TOKENS] = empty(DynArray[Token, MAX_TOKENS])
  found: DynArray[address, MAX_TOKENS] = empty(DynArray[address, MAX_TOKENS])

  for index in range(_offset, _offset + MAX_TOKENS):
    if len(col) == _limit or index >= counted:
      break

    pair_addr: address = pair_factory.allPairs(index)

    pair: IPair = IPair(pair_addr)
    token0: address = pair.token0()
    token1: address = pair.token1()

    if token0 not in found:
      col.append(self._token(token0, _account, _oracle, _oracle_connectors))
      found.append(token0)

    if token1 not in found:
      col.append(self._token(token1, _account, _oracle, _oracle_connectors))
      found.append(token1)

  return col

@internal
@view
def _prepend(
    _address: address,
    _to: DynArray[address, MAX_TOKENS],
  ) -> DynArray[address, MAX_TOKENS]:
  """Concatenates two arrays of addresses."""
  all: DynArray[address, MAX_TOKENS] = [_address]
  to_len: uint256 = len(_to)

  for index in range(0, MAX_TOKENS):
    if index >= to_len:
      break

    all.append(_to[index])

  return all

@internal
@view
def _token(
    _address: address,
    _account: address,
    _oracle: address,
    _oracle_connectors: DynArray[address, MAX_TOKENS]
  ) -> Token:
  token: IERC20 = IERC20(_address)
  bal: uint256 = empty(uint256)
  price: uint256 = empty(uint256)
  conns_len: uint256 = len(_oracle_connectors)

  if _oracle != empty(address) and conns_len > 0:
    conns: DynArray[address, MAX_TOKENS] = self._prepend(
      _address, _oracle_connectors
    )
    price = IOracle(_oracle).getRateWithConnectors(conns)

  if _account != empty(address):
    bal = token.balanceOf(_account)

  return Token({
    token_address: _address,
    symbol: token.symbol(),
    decimals: token.decimals(),
    account_balance: bal,
    price: price,
    price_decimals: 18
  })

@external
@view
def all(_limit: uint256, _offset: uint256, _account: address) \
    -> DynArray[Pair, MAX_PAIRS]:
  """
  @notice Returns a collection of pair data
  @param _limit The max amount of pairs to return
  @param _offset The amount of pairs to skip
  @param _account The account to check the staked and earned balances
  @return Array for Pair structs
  """
  pair_factory: IPairFactory = IPairFactory(self.pair_factory)
  counted: uint256 = pair_factory.allPairsLength()

  col: DynArray[Pair, MAX_PAIRS] = empty(DynArray[Pair, MAX_PAIRS])

  for index in range(_offset, _offset + MAX_PAIRS):
    if len(col) == _limit or index >= counted:
      break

    pair_addr: address = pair_factory.allPairs(index)

    col.append(self._byAddress(pair_addr, _account))

  return col

@external
@view
def byIndex(_index: uint256, _account: address) -> Pair:
  """
  @notice Returns pair data at a specific stored index
  @param _index The index to lookup
  @param _account The account to check the staked and earned balances
  @return Pair struct
  """
  pair_factory: IPairFactory = IPairFactory(self.pair_factory)

  return self._byAddress(pair_factory.allPairs(_index), _account)

@external
@view
def byAddress(_address: address, _account: address) -> Pair:
  """
  @notice Returns pair data based on the address
  @param _address The address to lookup
  @param _account The account to check the staked and earned balances
  @return Pair struct
  """
  return self._byAddress(_address, _account)

@internal
@view
def _byAddress(_address: address, _account: address) -> Pair:
  """
  @notice Returns pair data based on the address
  @param _address The address to lookup
  @param _account The user account
  @return Pair struct
  """
  assert _address != empty(address), 'Invalid address!'

  voter: IVoter = IVoter(self.voter)
  wrapped_bribe_factory: IWrappedBribeFactory = \
    IWrappedBribeFactory(self.wrapped_bribe_factory)
  token: IERC20 = IERC20(self.token)

  pair: IPair = IPair(_address)
  gauge: IGauge = IGauge(voter.gauges(_address))
  bribe_addr: address = voter.external_bribes(gauge.address)
  wrapped_bribe_addr: address = \
    wrapped_bribe_factory.oldBribeToNew(bribe_addr)

  token0: IERC20 = IERC20(pair.token0())
  token1: IERC20 = IERC20(pair.token1())

  earned: uint256 = 0
  acc_staked: uint256 = 0
  gauge_total_supply: uint256 = 0
  emissions: uint256 = 0

  if gauge.address != empty(address):
    acc_staked = gauge.balanceOf(_account)
    earned = gauge.earned(self.token, _account)
    gauge_total_supply = gauge.totalSupply()
    emissions = gauge.rewardRate(self.token)

  return Pair({
    pair_address: _address,
    symbol: pair.symbol(),
    decimals: pair.decimals(),
    stable: pair.stable(),
    total_supply: pair.totalSupply(),

    token0: token0.address,
    token0_symbol: token0.symbol(),
    token0_decimals: token0.decimals(),
    reserve0: pair.reserve0(),
    claimable0: pair.claimable0(_account),

    token1: token1.address,
    token1_symbol: token1.symbol(),
    token1_decimals: token1.decimals(),
    reserve1: pair.reserve1(),
    claimable1: pair.claimable1(_account),

    gauge: gauge.address,
    gauge_total_supply: gauge_total_supply,

    fee: voter.internal_bribes(gauge.address),
    bribe: bribe_addr,
    wrapped_bribe: wrapped_bribe_addr,

    emissions: emissions,
    emissions_token: self.token,
    emissions_token_decimals: token.decimals(),

    account_balance: pair.balanceOf(_account),
    account_earned: earned,
    account_staked: acc_staked,
    account_token0_balance: token0.balanceOf(_account),
    account_token1_balance: token1.balanceOf(_account)
  })

@external
@view
def epochsLatest(_limit: uint256, _offset: uint256) \
    -> DynArray[PairEpoch, MAX_PAIRS]:
  """
  @notice Returns all pairs latest epoch data (up to 200 items)
  @param _limit The max amount of pairs to check for epochs
  @param _offset The amount of pairs to skip
  @return Array for PairEpoch structs
  """
  pair_factory: IPairFactory = IPairFactory(self.pair_factory)
  pairs_count: uint256 = pair_factory.allPairsLength()
  counted: uint256 = 0

  col: DynArray[PairEpoch, MAX_PAIRS] = empty(DynArray[PairEpoch, MAX_PAIRS])

  for index in range(_offset, _offset + MAX_PAIRS):
    if counted == _limit or index >= pairs_count:
      break

    pair_addr: address = pair_factory.allPairs(index)

    latest: PairEpoch = self._epochLatestByAddress(pair_addr)

    if latest.ts != 0:
      col.append(latest)
      counted += 1

  return col

@external
@view
def epochsByAddress(_limit: uint256, _offset: uint256, _address: address) \
    -> DynArray[PairEpoch, MAX_EPOCHS]:
  """
  @notice Returns all pair epoch data based on the address
  @param _limit The max amount of epochs to return
  @param _offset The number of epochs to skip
  @param _address The address to lookup
  @return Array for PairEpoch structs
  """
  return self._epochsByAddress(_limit, _offset, _address)

@internal
@view
def _epochLatestByAddress(_address: address) -> PairEpoch:
  """
  @notice Returns latest pair epoch data based on the address
  @param _address The address to lookup
  @return A PairEpoch struct
  """
  assert _address != empty(address), 'Invalid address!'

  voter: IVoter = IVoter(self.voter)
  gauge: IGauge = IGauge(voter.gauges(_address))

  if gauge.address == empty(address):
    return empty(PairEpoch)

  bribe: IBribe = IBribe(voter.external_bribes(gauge.address))

  wrapped_bribe_factory: IWrappedBribeFactory = \
    IWrappedBribeFactory(self.wrapped_bribe_factory)
  wrapped_bribe_addr: address = \
    wrapped_bribe_factory.oldBribeToNew(bribe.address)

  # TODO: DRY things up
  epoch_start_ts: uint256 = block.timestamp - (block.timestamp % WEEK)
  epoch_end_ts: uint256 = epoch_start_ts + WEEK - 1

  gauge_supply_index: uint256 = gauge.getPriorSupplyIndex(epoch_end_ts)

  if gauge_supply_index == 0:
    return empty(PairEpoch)

  gauge_supply_cp: uint256[2] = gauge.supplyCheckpoints(gauge_supply_index)

  bribe_supply_cp: uint256[2] = bribe.supplyCheckpoints(
    bribe.getPriorSupplyIndex(epoch_end_ts)
  )

  # We need the closest latest two Gauge reward rate per token checkpoints
  # since the reward rate per token is derived from:
  #   prev_cp.rewardRatePerToken += (
  #     curr_cp.timestamp - prev_cp.timestamp
  #   ) * curr_rewardRate / curr_supply
  rrpt_cp: uint256[2] = gauge.getPriorRewardPerToken(
    self.token, gauge_supply_cp[0]
  )
  rrpt_prev_cp: uint256[2] = gauge.getPriorRewardPerToken(
    self.token, gauge_supply_cp[0] - 1
  )

  ts_delta: uint256 = rrpt_cp[1] - rrpt_prev_cp[1]
  rrpt_delta: uint256 = rrpt_cp[0] - rrpt_prev_cp[0]

  if ts_delta == 0:
    return empty(PairEpoch)

  return PairEpoch({
    ts: epoch_start_ts,
    pair_address: _address,
    votes: bribe_supply_cp[1],
    emissions: rrpt_delta * gauge_supply_cp[1] / ts_delta / PRECISION,
    bribes: self._epochBribes(epoch_start_ts, wrapped_bribe_addr),
    fees: self._epochFees(
      epoch_start_ts,
      voter.internal_bribes(gauge.address),
      gauge.address
    )
  })

@internal
@view
def _epochsByAddress(_limit: uint256, _offset: uint256, _address: address) \
    -> DynArray[PairEpoch, MAX_EPOCHS]:
  """
  @notice Returns all pair epoch data based on the address
  @param _limit The max amount of epochs to return
  @param _offset The number of epochs to skip
  @param _address The address to lookup
  @return Array for PairEpoch structs
  """
  assert _address != empty(address), 'Invalid address!'

  epochs: DynArray[PairEpoch, MAX_EPOCHS] = \
    empty(DynArray[PairEpoch, MAX_EPOCHS])

  voter: IVoter = IVoter(self.voter)
  gauge: IGauge = IGauge(voter.gauges(_address))

  if gauge.address == empty(address):
    return epochs

  bribe: IBribe = IBribe(voter.external_bribes(gauge.address))

  wrapped_bribe_factory: IWrappedBribeFactory = \
    IWrappedBribeFactory(self.wrapped_bribe_factory)
  wrapped_bribe_addr: address = \
    wrapped_bribe_factory.oldBribeToNew(bribe.address)

  curr_epoch_start_ts: uint256 = block.timestamp - (block.timestamp % WEEK)

  for weeks in range(_offset, _offset + MAX_EPOCHS):
    # TODO: DRY things up
    epoch_start_ts: uint256 = curr_epoch_start_ts - (weeks * WEEK)
    epoch_end_ts: uint256 = epoch_start_ts + WEEK - 1

    if len(epochs) == _limit or weeks >= MAX_EPOCHS:
      break

    gauge_supply_index: uint256 = gauge.getPriorSupplyIndex(epoch_end_ts)
    gauge_supply_cp: uint256[2] = gauge.supplyCheckpoints(gauge_supply_index)

    bribe_supply_cp: uint256[2] = bribe.supplyCheckpoints(
      bribe.getPriorSupplyIndex(epoch_end_ts)
    )

    # We need the closest latest two Gauge reward rate per token checkpoints
    # since the reward rate per token is derived from:
    #   prev_cp.rewardRatePerToken += (
    #     curr_cp.timestamp - prev_cp.timestamp
    #   ) * curr_rewardRate / curr_supply
    rrpt_cp: uint256[2] = gauge.getPriorRewardPerToken(
      self.token, gauge_supply_cp[0]
    )
    rrpt_prev_cp: uint256[2] = gauge.getPriorRewardPerToken(
      self.token, gauge_supply_cp[0] - 1
    )

    ts_delta: uint256 = rrpt_cp[1] - rrpt_prev_cp[1]
    rrpt_delta: uint256 = rrpt_cp[0] - rrpt_prev_cp[0]

    if ts_delta == 0:
      continue

    # Do not report gauge fees for previous epochs, already distributed
    gauge_address: address = empty(address)
    if len(epochs) == 0:
      gauge_address = gauge.address

    epochs.append(PairEpoch({
      ts: epoch_start_ts,
      pair_address: _address,
      votes: bribe_supply_cp[1],
      emissions: rrpt_delta * gauge_supply_cp[1] / ts_delta / PRECISION,
      bribes: self._epochBribes(epoch_start_ts, wrapped_bribe_addr),
      fees: self._epochFees(
        epoch_start_ts,
        voter.internal_bribes(gauge.address),
        gauge_address
      )
    }))

    # If we reach the last supply index...
    if gauge_supply_index == 0:
      break

  return epochs

@internal
@view
def _epochBribes(_ts: uint256, _wrapped_bribe: address) \
    -> DynArray[PairEpochBribe, MAX_REWARDS]:
  """
  @notice Returns pair bribes
  @param _ts The pair epoch start timestamp
  @param _wrapped_bribe The pair wrapped bribe address
  @return An array of `PairEpoch` structs
  """
  bribes: DynArray[PairEpochBribe, MAX_REWARDS] = \
    empty(DynArray[PairEpochBribe, MAX_REWARDS])

  if _wrapped_bribe == empty(address):
    return bribes

  bribe: IBribe = IBribe(_wrapped_bribe)
  bribes_len: uint256 = bribe.rewardsListLength()

  # Bribes have a 16 max rewards limit anyway...
  for bindex in range(MAX_REWARDS):
    if bindex >= bribes_len:
      break

    bribe_token: IERC20 = IERC20(bribe.rewards(bindex))
    bribe_amount: uint256 = bribe.tokenRewardsPerEpoch(bribe_token.address, _ts)

    if bribe_amount == 0:
      continue

    bribes.append(PairEpochBribe({
      token: bribe_token.address,
      decimals: bribe_token.decimals(),
      symbol: bribe_token.symbol(),
      amount: bribe_amount
    }))

  return bribes

@internal
@view
def _epochFees(_ts: uint256, _fee: address, _gauge: address) \
    -> DynArray[PairEpochBribe, MAX_REWARDS]:
  """
  @notice Returns pair fees
  @param _ts The pair epoch start timestamp
  @param _fee The pair gauge address
  @return An array of `PairEpochBribe` structs
  """
  fees: DynArray[PairEpochBribe, MAX_REWARDS] = \
    empty(DynArray[PairEpochBribe, MAX_REWARDS])

  if _fee == empty(address):
    return fees

  fee: IBribe = IBribe(_fee)
  fees_len: uint256 = fee.rewardsListLength()

  # Fetch _to be distributed_ fees from the Gauge
  gauge_fees: uint256[2] = [0, 0]
  if _gauge != empty(address):
    gauge_fees = [
      IGauge(_gauge).fees0(),
      IGauge(_gauge).fees1()
    ]

  for findex in range(2):
    fee_token: IERC20 = IERC20(fee.rewards(findex))
    fee_data: uint256[2] = fee.getPriorRewardPerToken(fee_token.address, _ts)

    if fee_data[0] > 0:
      fees.append(PairEpochBribe({
        token: fee_token.address,
        decimals: fee_token.decimals(),
        symbol: fee_token.symbol(),
        amount: fee_data[0] + gauge_fees[findex]
      }))

  return fees
