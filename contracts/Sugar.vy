# @version >=0.3.6 <0.4.0

from vyper.interfaces import ERC20Detailed

# @title Velodrome Finance Sugar v1
# @author stas
# @notice Methods to make Velodrome devs life easier.

# Structs

struct Pair:
  symbol: String[100]
  stable: bool
  total_supply: uint256

  token0: address
  token0_symbol: String[100]
  token0_decimals: uint8
  reserve0: uint256

  token1: address
  token1_symbol: String[100]
  token1_decimals: uint8
  reserve1: uint256

  gauge: address
  gauge_total_supply: uint256

  fee: address
  bribe: address
  wrapped_bribe: address

  emissions: uint256
  emissions_token: address
  emissions_token_decimals: uint8

# Our contracts / Interfaces

interface IPairFactory:
  def allPairsLength() -> uint256: view
  def allPairs(_index: uint256) -> address: view

interface IWrappedBribeFactory:
  def oldBribeToNew(_external_bribe_addr: address) -> address: view

interface IPair:
  def getReserves() -> uint256[3]: view
  def token0() -> address: view
  def token1() -> address: view
  def totalSupply() -> uint256: view
  def symbol() -> String[100]: view
  def decimals() -> uint8: view
  def stable() -> bool: view

interface IVoter:
  def factory() -> address: view
  def base() -> address: view
  def gauges(_pair_addr: address) -> address: view
  def external_bribes(_gauge_addr: address) -> address: view
  def internal_bribes(_gauge_addr: address) -> address: view

interface IGauge:
  def totalSupply() -> uint256: view
  def rewardRate(_token_addr: address) -> uint256: view

# Vars

pair_factory: public(address)
voter: public(address)
wrapped_bribe_factory: public(address)
token: public(address)

# Methods

@external
def __init__(_voter: address, _wrapped_bribe_factory: address):
  """
  @dev Sets up our contract addresses
  """
  voter: IVoter = IVoter(_voter)

  self.voter = _voter
  self.pair_factory = voter.factory()
  self.token = voter.base()
  self.wrapped_bribe_factory = _wrapped_bribe_factory

@external
@view
def pairs() -> DynArray[Pair, max_value(int128)]:
  """
  @notice Returns pair data
  @return Array for Pair structs
  """
  pair_factory: IPairFactory = IPairFactory(self.pair_factory)
  pairsCount: uint256 = pair_factory.allPairsLength()

  all: DynArray[Pair, max_value(int128)] = []

  for index in range(max_value(int128)):
    if index > pairsCount - 1:
      break

    all[index] = self.pairByAddress(pair_factory.allPairs(index))

  return all

@external
@view
def pairByIndex(_index: uint256) -> Pair:
  """
  @notice Returns pair data at a specific stored index
  @param _index The index to lookup
  @return Pair struct
  """
  pair_factory: IPairFactory = IPairFactory(self.pair_factory)

  return self.pairByAddress(pair_factory.allPairs(_index))

@internal
@view
def pairByAddress(_address: address) -> Pair:
  """
  @notice Returns pair data based on the address
  @param _address The address to lookup
  @return Pair struct
  """
  voter: IVoter = IVoter(self.voter)
  wrapped_bribe_factory: IWrappedBribeFactory = \
    IWrappedBribeFactory(self.wrapped_bribe_factory)
  token: ERC20Detailed = ERC20Detailed(self.token)

  pair: IPair = IPair(_address)
  gauge: IGauge = IGauge(voter.gauges(_address))
  bribe_addr: address = voter.external_bribes(gauge.address)
  wrapped_bribe_addr: address = \
    wrapped_bribe_factory.oldBribeToNew(bribe_addr)

  token0: ERC20Detailed = ERC20Detailed(pair.token0())
  token1: ERC20Detailed = ERC20Detailed(pair.token1())
  reserves: uint256[3] = pair.getReserves()

  return Pair({
    symbol: pair.symbol(),
    stable: pair.stable(),
    total_supply: pair.totalSupply(),

    token0: token0.address,
    token0_symbol: token0.symbol(),
    token0_decimals: token0.decimals(),
    reserve0: reserves[0],

    token1: token1.address,
    token1_symbol: token1.symbol(),
    token1_decimals: token1.decimals(),
    reserve1: reserves[1],

    gauge: gauge.address,
    gauge_total_supply: gauge.totalSupply(),

    fee: voter.internal_bribes(gauge.address),
    bribe: bribe_addr,
    wrapped_bribe: wrapped_bribe_addr,

    emissions: gauge.rewardRate(token.address),
    emissions_token: token.address,
    emissions_token_decimals: token.decimals()
  })
