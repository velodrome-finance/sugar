# SPDX-License-Identifier: BUSL-1.1
# @version >=0.3.6 <0.4.0

# @title Velodrome Finance Relay Sugar v2
# @author stas, ZoomerAnon
# @notice Makes it nicer to work with autocompounders.

MAX_COMPOUNDERS: constant(uint256) = 50
MAX_RESULTS: constant(uint256) = 1000
MAX_PAIRS: constant(uint256) = 30

struct LpVotes:
  lp: address
  weight: uint256

struct Relay:
  venft_id: uint256
  decimals: uint8
  amount: uint128
  voting_amount: uint256
  voted_at: uint256
  votes: DynArray[LpVotes, MAX_PAIRS]
  token: address
  manager: address
  compounder: address
  inactive: bool
  name: String[100]
  account_venft_ids: DynArray[uint256, MAX_RESULTS]

interface IVoter:
  def ve() -> address: view
  def lastVoted(_venft_id: uint256) -> uint256: view
  def poolVote(_venft_id: uint256, _index: uint256) -> address: view
  def votes(_venft_id: uint256, _lp: address) -> uint256: view
  def usedWeights(_venft_id: uint256) -> uint256: view

interface IVotingEscrow:
  def idToManaged(_venft_id: uint256) -> uint256: view
  def deactivated(_venft_id: uint256) -> bool: view
  def token() -> address: view
  def decimals() -> uint8: view
  def ownerOf(_venft_id: uint256) -> address: view
  def balanceOfNFT(_venft_id: uint256) -> uint256: view
  def locked(_venft_id: uint256) -> (uint128, uint256, bool): view
  def ownerToNFTokenIdList(_account: address, _index: uint256) -> uint256: view
  def voted(_venft_id: uint256) -> bool: view

interface IAutoCompounderFactory:
  def autoCompounders() -> DynArray[address, MAX_COMPOUNDERS]: view

interface IAutoCompounder:
  def name() -> String[100]: view
  def tokenId() -> uint256: view

# Vars
factory: public(IAutoCompounderFactory)
voter: public(IVoter)
ve: public(IVotingEscrow)
token: public(address)

@external
def __init__(_factory: address, _voter: address):
  """
  @dev Set up our external factory contract
  """
  self.factory = IAutoCompounderFactory(_factory)
  self.voter = IVoter(_voter)
  self.ve = IVotingEscrow(self.voter.ve())
  self.token = self.ve.token()

@external
@view
def all(_account: address) -> DynArray[Relay, MAX_COMPOUNDERS]:
  """
  @notice Returns all Relays and account's deposits
  @return Array of Relay structs
  """
  return self._autocompounders(_account)

@internal
@view
def _autocompounders(_account: address) -> DynArray[Relay, MAX_COMPOUNDERS]:
  """
  @notice Returns all Relays and account's deposits
  @return Array of Relay structs
  """
  compounders: DynArray[Relay, MAX_COMPOUNDERS] = empty(DynArray[Relay, MAX_COMPOUNDERS])
  addresses: DynArray[address, MAX_COMPOUNDERS] = self.factory.autoCompounders()

  for index in range(0, MAX_COMPOUNDERS):
    if index == len(addresses):
      break

    relay: Relay = self._byAddress(addresses[index], _account)
    compounders.append(relay)

  return compounders

@internal
@view
def _byAddress(_compounder: address, _account: address) -> Relay:
  """
  @notice Returns Relay data based on address, with optional account arg
  @param _id The Relay address to lookup
  @return Relay struct
  """
  
  autocompounder: IAutoCompounder = IAutoCompounder(_compounder)
  managed_id: uint256 = autocompounder.tokenId()

  account_venft_ids: DynArray[uint256, MAX_RESULTS] = empty(DynArray[uint256, MAX_RESULTS])

  for venft_index in range(MAX_RESULTS):
    account_venft_id: uint256 = self.ve.ownerToNFTokenIdList(_account, venft_index)

    if account_venft_id == 0:
      break
    
    account_venft_manager_id: uint256 = self.ve.idToManaged(account_venft_id)
    if account_venft_manager_id == managed_id:
      account_venft_ids.append(account_venft_id)

  votes: DynArray[LpVotes, MAX_PAIRS] = []
  amount: uint128 = self.ve.locked(managed_id)[0]
  last_voted: uint256 = 0
  manager: address = self.ve.ownerOf(managed_id)
  inactive: bool = self.ve.deactivated(managed_id)

  if self.ve.voted(managed_id):
    last_voted = self.voter.lastVoted(managed_id)

  vote_weight: uint256 = self.voter.usedWeights(managed_id)
  # Since we don't have a way to see how many pools the veNFT voted...
  left_weight: uint256 = vote_weight

  for index in range(MAX_PAIRS):
    if left_weight == 0:
      break

    lp: address = self.voter.poolVote(managed_id, index)

    if lp == empty(address):
      break

    weight: uint256 = self.voter.votes(managed_id, lp)

    votes.append(LpVotes({
      lp: lp,
      weight: weight
    }))

    # Remove _counted_ weight to see if there are other pool votes left...
    left_weight -= weight

  return Relay({
    venft_id: managed_id,
    decimals: self.ve.decimals(),
    amount: amount,
    voting_amount: self.ve.balanceOfNFT(managed_id),
    voted_at: last_voted,
    votes: votes,
    token: self.token,
    manager: manager,
    compounder: _compounder,
    inactive: inactive,
    name: autocompounder.name(),
    account_venft_ids: account_venft_ids
  })
