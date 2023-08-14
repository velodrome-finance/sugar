# SPDX-License-Identifier: BUSL-1.1
# @version >=0.3.6 <0.4.0

# @title Velodrome Finance Relay Sugar v2
# @author stas, ZoomerAnon
# @notice Makes it nicer to work with autocompounders.

MAX_COMPOUNDERS: constant(uint256) = 50
# Inherited from veSugar
MAX_RESULTS: constant(uint256) = 1000
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
  rebase_amount: uint256
  expires_at: uint256
  voted_at: uint256
  votes: DynArray[LpVotes, MAX_PAIRS]
  token: address
  permanent: bool

struct Deposit:
  deposited_nft: VeNFT
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

interface IVeSugar:
  def byId(_id: uint256) -> VeNFT: view
  def byAccount(_account: address) -> DynArray[VeNFT, MAX_RESULTS]: view

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
ve_sugar: public(IVeSugar)
ve: public(IVotingEscrow)

@external
def __init__(_factory: address, _ve_sugar: address, _ve: address):
  """
  @dev Set up our external factory contract
  """
  self.factory = IAutoCompounderFactory(_factory)
  self.ve_sugar = IVeSugar(_ve_sugar)
  self.ve = IVotingEscrow(_ve)

@external
@view
def all(_account: address) -> (DynArray[Relay, MAX_COMPOUNDERS], DynArray[RelayVeNFT, MAX_RESULTS]):
  """
  @notice Returns all AutoCompounders and account's deposits
  @return Array of Relay structs, Array of account's deposits
  """
  autocompounders: DynArray[Relay, MAX_COMPOUNDERS] = self._autocompounders()
  deposits: DynArray[Deposit, MAX_RESULTS] = self._deposits()

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
    managed_nft: VeNFT = self.ve_sugar.byId(managed_id)
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
def _deposits(_account: address) -> DynArray[Deposit, MAX_RESULTS]:
  """
  @notice Returns all of an account's Relay Deposits
  @param _account The account address
  @return Array of Deposits
  """
  deposits: DynArray[Deposit, MAX_RESULTS] = empty(DynArray[Deposit, MAX_RESULTS])
  nfts: DynArray[VeNFT, MAX_RESULTS] = self.ve_sugar.byAccount(_account)

  for index in range(0, len(nfts)):
    manager_id: uint256 = self.ve.idToManaged(nfts[index].id)

    if manager_id != 0:
      deposits.append(Deposit({
        deposited_nft: nfts[index],
        manager_id: manager_id
      }))

  return deposits
