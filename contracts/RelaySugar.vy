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

struct VeNFT:
  id: uint256
  decimals: uint8
  amount: uint128
  voting_amount: uint256
  voted_at: uint256
  votes: DynArray[LpVotes, MAX_PAIRS]
  token: address
  manager_id: uint256

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
def all(_account: address) -> (DynArray[Relay, MAX_COMPOUNDERS], DynArray[VeNFT, MAX_RESULTS]):
  """
  @notice Returns all AutoCompounders and account's deposits
  @return Array of Relay structs, Array of account's deposits
  """
  autocompounders: DynArray[Relay, MAX_COMPOUNDERS] = self._autocompounders()
  deposits: DynArray[VeNFT, MAX_RESULTS] = self._deposits()

  return autocompounders, deposits

@internal
@view
def _autocompounders(_account: address) -> DynArray[Relay, MAX_COMPOUNDERS]:
  """
  @notice Returns all AutoCompounders
  @return Array of AutoCompounder structs
  """
  compounders: DynArray[Relay, MAX_COMPOUNDERS] = empty(DynArray[Relay, MAX_COMPOUNDERS])
  addresses: DynArray[address, MAX_COMPOUNDERS] = self.factory.autoCompounders()
  account_venfts: DynArray[(uint256, uint256), MAX_RESULTS] = empty(DynArray[(uint256, uint256), MAX_RESULTS])

  for venft_index in range(MAX_RESULTS):
    account_venft_id: uint256 = self.ve.ownerToNFTokenIdList(_account, venft_index)

    if account_venft_id == 0:
      break
    
    account_venft_manager_id: uint256 = self.ve.idToManaged(account_venft_id)
    account_venfts.append(account_venft_manager_id, account_venft_id)
  
  for index in range(0, len(addresses)):
    autocompounder: IAutoCompounder = IAutoCompounder(addresses[index])
    managed_id: uint256 = autocompounder.tokenId()
    managed_nft: VeNFT = self._byId(managed_id)
    inactive: bool = self.ve.deactivated(managed_id)
    manager: address = self.ve.ownerOf(managed_id)
    account_venft_ids: DynArray[uint256, MAX_RESULTS] = empty(DynArray[uint256, MAX_RESULTS])

    for venft_index in range(0, len(account_venfts)):
      if managed_id == account_venfts[venft_index][0]:
        account_venft_ids.append(account_venfts[venft_index][1])

    compounders.append(Relay({
      venft_id: managed_id,
      decimals: managed_nft.decimals,
      amount: managed_nft.amount,
      voting_amount: managed_nft.voting_amount,
      voted_at: managed_nft.voted_at,
      votes: managed_nft.votes,
      token: managed_nft.token,
      manager: manager,
      compounder: addresses[index],
      inactive: inactive,
      name: autocompounder.name(),
      account_venft_ids: account_venft_ids
    }))

  return compounders

@internal
@view
def _deposits(_account: address) -> DynArray[VeNFT, MAX_RESULTS]:
  """
  @notice Returns all of an account's Relay veNFT deposits
  @param _account The account address
  @return Array of VeNFTs
  """
  deposits: DynArray[VeNFT, MAX_RESULTS] = empty(DynArray[VeNFT, MAX_RESULTS])

  if _account == empty(address):
    return deposits

  for index in range(MAX_RESULTS):
    venft_id: uint256 = self.ve.ownerToNFTokenIdList(_account, index)

    if venft_id == 0:
      break

    manager_id: uint256 = self.ve.idToManaged(venft_id)

    if manager_id != 0:
      deposits.append(self._byId(venft_id))

  return deposits

@internal
@view
def _byId(_id: uint256) -> VeNFT:
  """
  @notice Returns veNFT data based on ID
  @param _id The index/ID to lookup
  @return VeNFT struct
  """
  votes: DynArray[LpVotes, MAX_PAIRS] = []
  amount: uint128 = 0
  amount = self.ve.locked(_id)[0]
  last_voted: uint256 = 0
  manager_id: uint256 = self.ve.idToManaged(_id)

  if self.ve.voted(_id):
    last_voted = self.voter.lastVoted(_id)

  vote_weight: uint256 = self.voter.usedWeights(_id)
  # Since we don't have a way to see how many pools the veNFT voted...
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
    decimals: self.ve.decimals(),
    amount: amount,
    voting_amount: self.ve.balanceOfNFT(_id),
    voted_at: last_voted,
    votes: votes,
    token: self.token,
    manager_id: manager_id
  })
