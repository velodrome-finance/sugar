# @version >=0.3.6 <0.4.0

# @title Velodrome Finance Liquidity Pairs Sugar v1
# @author stas
# @notice Makes it nicer to work with the liquidity pairs.

# Structs

MAX_PAIRS: constant(uint256) = 1000

struct Pair:
  pair_address: address
  symbol: String[100]
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

# Our contracts / Interfaces

interface IERC20:
  def decimals() -> uint8: view
  def symbol() -> String[100]: view

interface IPairFactory:
  def allPairsLength() -> uint256: view
  def allPairs(_index: uint256) -> address: view

interface IWrappedBribeFactory:
  def oldBribeToNew(_external_bribe_addr: address) -> address: view
  def voter() -> address: view

interface IPair:
  def getReserves() -> uint256[3]: view
  def token0() -> address: view
  def token1() -> address: view
  def claimable0(_account: address) -> uint256: view
  def claimable1(_account: address) -> uint256: view
  def totalSupply() -> uint256: view
  def symbol() -> String[100]: view
  def decimals() -> uint8: view
  def stable() -> bool: view

interface IVoter:
  def _ve() -> address: view
  def factory() -> address: view
  def gauges(_pair_addr: address) -> address: view
  def external_bribes(_gauge_addr: address) -> address: view
  def internal_bribes(_gauge_addr: address) -> address: view

interface IVotingEscrow:
  def token() -> address: view

interface IGauge:
  def earned(_token: address, _account: address) -> uint256: view
  def balanceOf(_account: address) -> uint256: view
  def totalSupply() -> uint256: view
  def rewardRate(_token_addr: address) -> uint256: view

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
  return self._byAddress(_address, _address)

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
  reserves: uint256[3] = pair.getReserves()

  earned: uint256 = 0
  acc_balance: uint256 = 0
  gauge_total_supply: uint256 = 0
  emissions: uint256 = 0

  if gauge.address != empty(address):
    acc_balance = gauge.balanceOf(_account)
    earned = gauge.earned(self.token, _account)
    gauge_total_supply = gauge.totalSupply()
    emissions = gauge.rewardRate(self.token)

  return Pair({
    pair_address: _address,
    symbol: pair.symbol(),
    stable: pair.stable(),
    total_supply: pair.totalSupply(),

    token0: token0.address,
    token0_symbol: token0.symbol(),
    token0_decimals: token0.decimals(),
    reserve0: reserves[0],
    claimable0: pair.claimable0(_account),

    token1: token1.address,
    token1_symbol: token1.symbol(),
    token1_decimals: token1.decimals(),
    reserve1: reserves[1],
    claimable1: pair.claimable1(_account),

    gauge: gauge.address,
    gauge_total_supply: gauge_total_supply,

    fee: voter.internal_bribes(gauge.address),
    bribe: bribe_addr,
    wrapped_bribe: wrapped_bribe_addr,

    emissions: emissions,
    emissions_token: self.token,
    emissions_token_decimals: token.decimals(),

    account_balance: acc_balance,
    account_earned: earned
  })
