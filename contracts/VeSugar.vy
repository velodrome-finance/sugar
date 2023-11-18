# SPDX-License-Identifier: BUSL-1.1
# @version >=0.3.6 <0.4.0

# @title Aerodrome Finance veNFT Sugar v2
# @author stas
# @notice Makes it nicer to work with our vote-escrow NFTs.

MAX_RESULTS: constant(uint256) = 1000
# Basically max gauges for a veNFT, this one is tricky, but
# we can't go crazy with it due to memory limitations...
MAX_PAIRS: constant(uint256) = 30

struct LpVotes:
  lp: address
  weight: uint256

struct VeNFT:
  id: uint256
  account: address
  decimals: uint8
  amount: uint128
  voting_amount: uint256
  governance_amount: uint256
  rebase_amount: uint256
  expires_at: uint256
  voted_at: uint256
  votes: DynArray[LpVotes, MAX_PAIRS]
  token: address
  permanent: bool
  delegate_id: uint256

# Our contracts / Interfaces

interface IVoter:
  def ve() -> address: view
  def gauges(_lp: address) -> address: view
  def gaugeToBribe(_gauge_addr: address) -> address: view
  def gaugeToFees(_gauge_addr: address) -> address: view
  def lastVoted(_venft_id: uint256) -> uint256: view
  def poolVote(_venft_id: uint256, _index: uint256) -> address: view
  def votes(_venft_id: uint256, _lp: address) -> uint256: view
  def usedWeights(_venft_id: uint256) -> uint256: view

interface IRewardsDistributor:
  def ve() -> address: view
  def claimable(_venft_id: uint256) -> uint256: view

interface IVotingEscrow:
  def token() -> address: view
  def decimals() -> uint8: view
  def ownerOf(_venft_id: uint256) -> address: view
  def balanceOfNFT(_venft_id: uint256) -> uint256: view
  def locked(_venft_id: uint256) -> (uint128, uint256, bool): view
  def ownerToNFTokenIdList(_account: address, _index: uint256) -> uint256: view
  def voted(_venft_id: uint256) -> bool: view
  def delegates(_venft_id: uint256) -> uint256: view
  def idToManaged(_venft_id: uint256) -> uint256: view

interface IGovernor:
  def getVotes(_venft_id: uint256, _timepoint: uint256) -> uint256: view

# Vars

voter: public(IVoter)
token: public(address)
ve: public(IVotingEscrow)
dist: public(IRewardsDistributor)
gov: public(IGovernor)

# Methods

@external
def __init__(_voter: address, _rewards_distributor: address, _gov: address):
  """
  @dev Sets up our external contract addresses
  """
  self.voter = IVoter(_voter)
  self.ve = IVotingEscrow(self.voter.ve())
  self.token = self.ve.token()
  self.dist = IRewardsDistributor(_rewards_distributor)
  self.gov = IGovernor(_gov)

@external
@view
def all(_limit: uint256, _offset: uint256) -> DynArray[VeNFT, MAX_RESULTS]:
  """
  @notice Returns a collection of veNFT data
  @param _limit The max amount of veNFTs to return
  @param _offset The amount of veNFTs to skip
  @return Array for VeNFT structs
  """
  col: DynArray[VeNFT, MAX_RESULTS] = empty(DynArray[VeNFT, MAX_RESULTS])

  for index in range(_offset, _offset + MAX_RESULTS):
    if len(col) == _limit:
      break

    if self.ve.ownerOf(index) == empty(address):
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

  if _account == empty(address):
    return col

  for index in range(MAX_RESULTS):
    venft_id: uint256 = self.ve.ownerToNFTokenIdList(_account, index)

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
  account: address = self.ve.ownerOf(_id)

  if account == empty(address):
    return empty(VeNFT)

  votes: DynArray[LpVotes, MAX_PAIRS] = []
  amount: uint128 = 0
  expires_at: uint256 = 0
  perma: bool = False
  amount, expires_at, perma = self.ve.locked(_id)
  last_voted: uint256 = 0
  governance_amount: uint256 = self.gov.getVotes(_id, block.timestamp)

  delegate_id: uint256 = self.ve.delegates(_id)
  managed_id: uint256 = self.ve.idToManaged(_id)

  if managed_id != 0 or self.ve.voted(_id):
    last_voted = self.voter.lastVoted(_id)

  vote_weight: uint256 = self.voter.usedWeights(_id)
  # Since we don't have a way to see how many pools we voted...
  left_weight: uint256 = vote_weight

  for index in range(MAX_PAIRS):
    if left_weight == 0:
      break

    lp: address = self.voter.poolVote(_id, index)

    if lp == empty(address):
      break

    weight: uint256 = self.voter.votes(_id, lp)

    votes.append(LpVotes({
      lp: lp,
      weight: weight
    }))

    # Remove _counted_ weight to see if there are other pool votes left...
    left_weight -= weight

  return VeNFT({
    id: _id,
    account: account,
    decimals: self.ve.decimals(),

    amount: amount,
    voting_amount: self.ve.balanceOfNFT(_id),
    governance_amount: governance_amount,
    rebase_amount: self.dist.claimable(_id),
    expires_at: expires_at,
    voted_at: last_voted,
    votes: votes,
    token: self.token,
    permanent: perma,
    delegate_id: delegate_id
  })
