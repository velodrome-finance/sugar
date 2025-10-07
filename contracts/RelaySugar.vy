# SPDX-License-Identifier: BUSL-1.1
# @version ^0.4.0

# @title Velodrome Finance Relay Sugar v2
# @author stas, ZoomerAnon
# @notice Makes it nicer to work with Relay.

MAX_RELAYS: constant(uint256) = 150
MAX_RESULTS: constant(uint256) = 50
MAX_PAIRS: constant(uint256) = 30
MAX_REGISTRIES: constant(uint256) = 12
WEEK: constant(uint256) = 7 * 24 * 60 * 60

struct LpVotes:
  lp: address
  weight: uint256

struct ManagedVenft:
  id: uint256
  amount: uint256
  earned: uint256

struct Relay:
  venft_id: uint256
  decimals: uint8
  amount: uint128
  voting_amount: uint256
  used_voting_amount: uint256
  voted_at: uint256
  votes: DynArray[LpVotes, MAX_PAIRS]
  token: address
  compounded: uint256
  withdrawable: uint256
  run_at: uint256
  manager: address
  relay: address
  compounder: bool
  inactive: bool
  name: String[100]
  account_venfts: DynArray[ManagedVenft, MAX_RESULTS]


interface IERC20:
  def balanceOf(_account: address) -> uint256: view

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
  def managedToLocked(_managed_venft_id: uint256) -> address: view
  def weights(_venft_id: uint256, _managed_venft_id: uint256) -> uint256: view

interface IReward:
  def earned(_token: address, _venft_id: uint256) -> uint256: view

interface IRelayRegistry:
  def getAll() -> DynArray[address, MAX_RELAYS]: view

interface IRelayFactory:
  def relays() -> DynArray[address, MAX_RELAYS]: view

interface IRelay:
  def name() -> String[100]: view
  def mTokenId() -> uint256: view
  def token() -> address: view
  def keeperLastRun() -> uint256: view
  # Latest epoch rewards
  def amountTokenEarned(_epoch_ts: uint256) -> uint256: view
  def DEFAULT_ADMIN_ROLE() -> bytes32: view
  def getRoleMember(_role: bytes32, _index: uint256) -> address: view

interface ISwapper:
  def amountTokenEarned(_autoConverter: address, _epoch: uint256) -> uint256: view

# Vars
registries: public(DynArray[address, MAX_REGISTRIES])
voter: public(IVoter)
swapper: public(ISwapper)
ve: public(IVotingEscrow)
token: public(address)

@deploy
def __init__(_registries: DynArray[address, MAX_REGISTRIES], _voter: address, _swapper: address):
  """
  @dev Set up our external registry, voter, swapper contracts
  """
  self.registries = _registries
  self.voter = IVoter(_voter)
  self.swapper = ISwapper(_swapper)
  self.ve = IVotingEscrow(staticcall self.voter.ve())
  self.token = staticcall self.ve.token()

@external
@view
def all(_account: address) -> DynArray[Relay, MAX_RELAYS]:
  """
  @notice Returns all Relays and account's deposits
  @return Array of Relay structs
  """
  return self._relays(_account)

@internal
@view
def _relays(_account: address) -> DynArray[Relay, MAX_RELAYS]:
  """
  @notice Returns all Relays and account's deposits
  @return Array of Relay structs
  """
  relays: DynArray[Relay, MAX_RELAYS] = empty(DynArray[Relay, MAX_RELAYS])
  relay_count: uint256 = 0
  for registry_index: uint256 in range(0, MAX_REGISTRIES):
    if registry_index == len(self.registries):
      break

    relay_registry: IRelayRegistry = IRelayRegistry(self.registries[registry_index])
    factories: DynArray[address, MAX_RELAYS] = staticcall relay_registry.getAll()

    for factory_index: uint256 in range(0, MAX_RELAYS):
      if factory_index == len(factories):
        break

      relay_factory: IRelayFactory = IRelayFactory(factories[factory_index])
      addresses: DynArray[address, MAX_RELAYS] = staticcall relay_factory.relays()

      for index: uint256 in range(0, MAX_RELAYS):
        if index == len(addresses):
          break

        relay: Relay = self._byAddress(addresses[index], _account)
        relays.append(relay)

        relay_count += 1
        if relay_count == MAX_RELAYS:
          return relays

  return relays

@internal
@view
def _byAddress(_relay: address, _account: address) -> Relay:
  """
  @notice Returns Relay data based on address, with optional account arg
  @param _relay The Relay address to lookup
  @param _account The account address to lookup deposits
  @return Relay struct
  """

  relay: IRelay = IRelay(_relay)
  managed_id: uint256 = staticcall relay.mTokenId()

  account_venfts: DynArray[ManagedVenft, MAX_RESULTS] = empty(DynArray[ManagedVenft, MAX_RESULTS])

  for venft_index: uint256 in range(MAX_RESULTS):
    account_venft_id: uint256 = staticcall self.ve.ownerToNFTokenIdList(_account, venft_index)

    if account_venft_id == 0:
      break

    account_venft_manager_id: uint256 = staticcall self.ve.idToManaged(account_venft_id)
    if account_venft_manager_id == managed_id:
      locked_reward: IReward = IReward(staticcall self.ve.managedToLocked(account_venft_manager_id))
      venft_weight: uint256 = staticcall self.ve.weights(account_venft_id, account_venft_manager_id)
      earned: uint256 = staticcall locked_reward.earned(self.token, account_venft_id)

      account_venfts.append(
        ManagedVenft(id=account_venft_id, amount=venft_weight, earned=earned)
      )

  votes: DynArray[LpVotes, MAX_PAIRS] = []
  amount: uint128 = (staticcall self.ve.locked(managed_id))[0]
  last_voted: uint256 = 0
  withdrawable: uint256 = 0
  inactive: bool = staticcall self.ve.deactivated(managed_id)
  rewards_compounded: uint256 = 0

  admin_role: bytes32 = staticcall relay.DEFAULT_ADMIN_ROLE()
  manager: address = staticcall relay.getRoleMember(admin_role, 0)

  # If the Relay is an AutoConverter, fetch withdrawable amount
  relay_token: address = staticcall relay.token()
  if self.token != relay_token:
    token: IERC20 = IERC20(relay_token)
    withdrawable = staticcall token.balanceOf(_relay)

  epoch_start_ts: uint256 = block.timestamp // WEEK * WEEK
  is_compounder: bool = self._is_compounder(_relay)
  
  # Rewards claimed this epoch
  if is_compounder:
    rewards_compounded = staticcall relay.amountTokenEarned(epoch_start_ts)
  else:
    rewards_compounded = staticcall self.swapper.amountTokenEarned(_relay, epoch_start_ts)

  if staticcall self.ve.voted(managed_id):
    last_voted = staticcall self.voter.lastVoted(managed_id)

  vote_weight: uint256 = staticcall self.voter.usedWeights(managed_id)
  # Since we don't have a way to see how many pools the veNFT voted...
  left_weight: uint256 = vote_weight

  for index: uint256 in range(MAX_PAIRS):
    if left_weight == 0:
      break

    lp: address = staticcall self.voter.poolVote(managed_id, index)

    if lp == empty(address):
      break

    weight: uint256 = staticcall self.voter.votes(managed_id, lp)

    votes.append(
      LpVotes(lp=lp, weight=weight)
    )

    # Remove _counted_ weight to see if there are other pool votes left...
    left_weight -= weight

  return Relay(
    venft_id=managed_id,
    decimals=staticcall self.ve.decimals(),
    amount=amount,
    voting_amount=staticcall self.ve.balanceOfNFT(managed_id),
    used_voting_amount=vote_weight,
    voted_at=last_voted,
    votes=votes,
    token=relay_token,
    compounded=rewards_compounded,
    withdrawable=withdrawable,
    run_at=staticcall relay.keeperLastRun(),
    manager=manager,
    relay=_relay,
    compounder=is_compounder,
    inactive=inactive,
    name=staticcall relay.name(),
    account_venfts=account_venfts
  )

@internal
@view
def _is_compounder(_relay: address) -> bool:
  """
  @notice Returns true if the given Relay is an autocompounder, returns false otherwise
  @param _relay The Relay to call
  """
  return raw_call(
      _relay,
      method_id("autoCompounderFactory()"),
      max_outsize=64,
      gas=100000,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[0]
