# @version >=0.3.6 <0.4.0

# @title Velodrome Finance veNFT Sugar v1
# @author stas
# @notice Makes it nicer to work with our vote-escrow NFTs.
# @dev Refactor pair-related stuff when library modules support is released:
#       https://github.com/vyperlang/vyper/pull/2888

MAX_RESULTS: constant(uint256) = 1000
# Basically max attachments/gauges for a veNFT, this one is tricky, but
# we can't go crazy with it due to memory limitations...
MAX_PAIRS: constant(uint256) = 30

# Structs

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

struct PairVotes:
  pair: address
  weight: uint256

struct VeNFT:
  id: uint256
  account: address
  decimals: uint8
  amount: uint128
  voting_amount: uint256
  rebase_amount: uint256
  expires_at: uint256
  voted_at: uint256
  votes: DynArray[PairVotes, MAX_PAIRS]

  token: address
  token_decimals: uint8
  token_symbol: String[100]

struct Reward:
  venft_id: uint256
  pair: address
  amount: uint256
  token: address
  token_symbol: String[100]
  token_decimals: uint8
  fee: address
  bribe: address

# Our contracts / Interfaces

interface IERC20:
  def decimals() -> uint8: view
  def symbol() -> String[100]: view

interface IVoter:
  def _ve() -> address: view
  def lastVoted(_venft_id: uint256) -> uint256: view
  def poolVote(_venft_id: uint256, _index: uint256) -> address: view
  def votes(_venft_id: uint256, _pair: address) -> uint256: view
  def usedWeights(_venft_id: uint256) -> uint256: view

interface IRewardsDistributor:
  def voting_escrow() -> address: view
  def claimable(_venft_id: uint256) -> uint256: view

interface IVotingEscrow:
  def token() -> address: view
  def decimals() -> uint8: view
  def ownerOf(_venft_id: uint256) -> address: view
  def balanceOfNFT(_venft_id: uint256) -> uint256: view
  def locked(_venft_id: uint256) -> (uint128, uint256): view
  def tokenOfOwnerByIndex(_account: address, _index: uint256) -> uint256: view

interface IBribe:
  def rewardsListLength() -> uint256: view
  def rewards(_index: uint256) -> address: view
  def earned(_token: address, _venft_id: uint256) -> uint256: view

interface IPairFactory:
  def allPairsLength() -> uint256: view

interface IPairsSugar:
  def byIndex(_index: uint256, _account: address) -> Pair: view
  def byAddress(_address: address, _account: address) -> Pair: view
  def pair_factory() -> address: view

# Vars

voter: public(address)
token: public(address)
ve: public(address)
rewards_distributor: public(address)
pairs_sugar: public(address)
pair_factory: public(address)
owner: public(address)

# Methods

@external
def __init__():
  """
  @dev Sets up our contract management address
  """
  self.owner = msg.sender

@external
def setup(
    _voter: address,
    _rewards_distributor: address,
    _pairs_sugar: address
  ):
  """
  @dev Sets up our external contract addresses
  """
  assert self.owner == msg.sender, 'Not allowed!'

  voter: IVoter = IVoter(_voter)
  rewards_distributor: IRewardsDistributor = \
    IRewardsDistributor(_rewards_distributor)

  assert rewards_distributor.voting_escrow() == voter._ve(), 'VE mismatch!'

  self.voter = _voter
  self.ve = voter._ve()
  self.token = IVotingEscrow(self.ve).token()
  self.rewards_distributor = _rewards_distributor
  self.pairs_sugar = _pairs_sugar
  self.pair_factory = IPairsSugar(_pairs_sugar).pair_factory()

@external
@view
def all(_limit: uint256, _offset: uint256) -> DynArray[VeNFT, MAX_RESULTS]:
  """
  @notice Returns a collection of veNFT data
  @param _limit The max amount of veNFTs to return
  @param _offset The amount of veNFTs to skip
  @return Array for VeNFT structs
  """
  ve: IVotingEscrow = IVotingEscrow(self.ve)
  col: DynArray[VeNFT, MAX_RESULTS] = empty(DynArray[VeNFT, MAX_RESULTS])

  for index in range(_offset, _offset + MAX_RESULTS):
    if len(col) == _limit:
      break

    if ve.ownerOf(index) == empty(address):
      continue

    col.append(self._byId(index))

  return col

@external
@view
def byAccount(_account: address) -> DynArray[VeNFT, MAX_RESULTS]:
  """
  @notice Returns user collection of veNFT data
  @param _account The account address
  @return Array for VeNFT structs
  """
  col: DynArray[VeNFT, MAX_RESULTS] = empty(DynArray[VeNFT, MAX_RESULTS])
  ve: IVotingEscrow = IVotingEscrow(self.ve)

  if _account == empty(address):
    return col

  for index in range(MAX_RESULTS):
    venft_id: uint256 = ve.tokenOfOwnerByIndex(_account, index)

    if venft_id == 0:
      break

    col.append(self._byId(venft_id))

  return col

@external
@view
def byId(_id: uint256) -> VeNFT:
  """
  @notice Returns VeNFT data at a specific stored index
  @param _id The index to lookup
  @return VeNFT struct
  """
  return self._byId(_id)

@internal
@view
def _byId(_id: uint256) -> VeNFT:
  """
  @notice Returns VeNFT data based on the index/ID
  @param _id The index/ID to lookup
  @return VeNFT struct
  """
  ve: IVotingEscrow = IVotingEscrow(self.ve)

  account: address = ve.ownerOf(_id)

  if account == empty(address):
    return empty(VeNFT)

  voter: IVoter = IVoter(self.voter)
  dist: IRewardsDistributor = IRewardsDistributor(self.rewards_distributor)
  token: IERC20 = IERC20(self.token)

  votes: DynArray[PairVotes, MAX_PAIRS] = []
  amount: uint128 = 0
  expires_at: uint256 = 0
  amount, expires_at = ve.locked(_id)

  vote_weight: uint256 = voter.usedWeights(_id)
  # Since we don't have a way to see how many pairs we voted...
  left_weight: uint256 = vote_weight

  for index in range(MAX_PAIRS):
    if left_weight == 0:
      break

    pair_address: address = voter.poolVote(_id, index)

    if pair_address == empty(address):
      break

    weight: uint256 = voter.votes(_id, pair_address)

    votes.append(PairVotes({
      pair: pair_address,
      weight: weight
    }))

    # Remove _counted_ weight to see if there are other pair votes left...
    left_weight -= weight

  return VeNFT({
    id: _id,
    account: account,
    decimals: ve.decimals(),

    amount: amount,
    voting_amount: ve.balanceOfNFT(_id),
    rebase_amount: dist.claimable(_id),
    expires_at: expires_at,
    voted_at: voter.lastVoted(_id),
    votes: votes,

    token: token.address,
    token_decimals: token.decimals(),
    token_symbol: token.symbol()
  })

@external
@view
def rewards(_limit: uint256, _offset: uint256, _venft_id: uint256) \
    -> DynArray[Reward, MAX_RESULTS]:
  """
  @notice Returns a collection of veNFT rewards data
  @param _limit The max amount of pairs to check for rewards
  @param _offset The amount of pairs to skip checking for rewards
  @param _venft_id The veNFT ID to get rewards for
  @return Array for VeNFT Reward structs
  """
  psugar: IPairsSugar = IPairsSugar(self.pairs_sugar)
  col: DynArray[Reward, MAX_RESULTS] = empty(DynArray[Reward, MAX_RESULTS])

  pairs_count: uint256 = IPairFactory(self.pair_factory).allPairsLength()

  for pindex in range(_offset, _offset + MAX_RESULTS):
    if len(col) == _limit or pindex >= pairs_count:
      break

    # Do not send the `msg.sender` to save gas...
    pair: Pair = psugar.byIndex(pindex, empty(address))
    pcol: DynArray[Reward, MAX_RESULTS] = \
      self._pairRewards(_venft_id, pair)

    # Basically merge pair rewards to the rest of the rewards...
    for cindex in range(MAX_RESULTS):
      if cindex >= len(pcol):
        break

      col.append(pcol[cindex])

  return col

@external
@view
def rewardsByPair(_venft_id: uint256, _pair: address) \
    -> DynArray[Reward, MAX_RESULTS]:
  """
  @notice Returns a collection of veNFT rewards data for a specific pair
  @param _venft_id The veNFT ID to get rewards for
  @param _pair The pair address to get rewards for
  @return Array for VeNFT Reward structs
  """
  psugar: IPairsSugar = IPairsSugar(self.pairs_sugar)
  # Do not send the `msg.sender` to save gas...
  pair: Pair = psugar.byAddress(_pair, empty(address))

  return self._pairRewards(_venft_id, pair)

@internal
@view
def _pairRewards(_venft_id: uint256, _pair: Pair) \
    -> DynArray[Reward, MAX_RESULTS]:
  """
  @notice Returns a collection with veNFT pair rewards
  @param _venft_id The veNFT ID to get rewards for
  @param _pair The `Pair` sturct to work with
  @param _col The array of `Reward` sturcts to update
  """
  col: DynArray[Reward, MAX_RESULTS] = empty(DynArray[Reward, MAX_RESULTS])

  if _pair.pair_address == empty(address):
    return col

  if _pair.gauge == empty(address):
    return col

  fee0_amount: uint256 = IBribe(_pair.fee).earned(_pair.token0, _venft_id)
  fee1_amount: uint256 = IBribe(_pair.fee).earned(_pair.token1, _venft_id)

  if fee0_amount > 0:
    col.append(
      Reward({
        venft_id: _venft_id,
        pair: _pair.pair_address,
        amount: fee0_amount,
        token: _pair.token0,
        token_symbol: _pair.token0_symbol,
        token_decimals: _pair.token0_decimals,
        fee: _pair.fee,
        bribe: empty(address)
      })
    )

  if fee1_amount > 0:
    col.append(
      Reward({
        venft_id: _venft_id,
        pair: _pair.pair_address,
        amount: fee1_amount,
        token: _pair.token1,
        token_symbol: _pair.token1_symbol,
        token_decimals: _pair.token1_decimals,
        fee: _pair.fee,
        bribe: empty(address)
      })
    )

  if _pair.wrapped_bribe == empty(address):
    return col

  bribe: IBribe = IBribe(_pair.wrapped_bribe)
  bribes_len: uint256 = bribe.rewardsListLength()

  # Bribes have a 16 max rewards limit anyway...
  for bindex in range(MAX_PAIRS):
    if bindex >= bribes_len:
      break

    bribe_token: IERC20 = IERC20(bribe.rewards(bindex))
    bribe_amount: uint256 = bribe.earned(bribe_token.address, _venft_id)

    if bribe_amount == 0:
      break

    col.append(
      Reward({
        venft_id: _venft_id,
        pair: _pair.pair_address,
        amount: bribe_amount,
        token: bribe_token.address,
        token_symbol: bribe_token.symbol(),
        token_decimals: bribe_token.decimals(),
        fee: empty(address),
        bribe: _pair.wrapped_bribe
      })
    )

  return col
