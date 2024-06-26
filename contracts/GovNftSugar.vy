# SPDX-License-Identifier: BUSL-1.1
# @version ^0.3.10

# @title GovNFT Sugar
# @author ZoomerAnon
# @notice Makes it nicer to work with GovNFTs.

# Constants

MAX_COLLECTIONS: constant(uint256) = 50
MAX_RESULTS: constant(uint256) = 300
MAX_NFTS: constant(uint256) = 2000

# Structs

# Lock struct from GovNFT.sol
struct Lock:
  total_locked: uint256
  initial_deposit: uint256
  total_claimed: uint256
  unclaimed_before_split: uint256
  token: address
  split_count: uint40
  cliff_length: uint40
  start: uint40
  end: uint40
  vault: address
  minter: address

# Representation of an individual GovNFT
struct GovNft:
  id: uint256
  total_locked: uint256 # total locked amount
  amount: uint256 # current locked amount
  total_claimed: uint256
  claimable: uint256
  split_count: uint40
  cliff_length: uint40
  start: uint40
  end: uint40
  token: address
  vault: address
  minter: address
  owner: address
  address: address # address of GovNFT
  delegated: address # address of delegate

# Representation of a GovNFT collection created by the factory
struct Collection:
  address: address
  owner: address
  name: String[100]
  symbol: String[100]
  supply: uint256

# Contracts / Interfaces

interface IGovNFTFactory:
  def govNFTs() -> DynArray[address, MAX_COLLECTIONS]: view

interface IGovNFT:
  def balanceOf(_account: address) -> uint256: view
  def tokenOfOwnerByIndex(_account: address, _index: uint256) -> uint256: view
  def totalSupply() -> uint256: view
  def ownerOf(_govnft_id: uint256) -> address: view
  def locks(_govnft_id: uint256) -> Lock: view
  def unclaimed(_govnft_id: uint256) -> uint256: view
  def locked(_govnft_id: uint256) -> uint256: view
  def name() -> String[100]: view
  def symbol() -> String[100]: view
  def owner() -> address: view

interface IToken:
  def delegates(_account: address) -> address: view

# Vars
factory: public(IGovNFTFactory)

# Methods

@external
def __init__(_factory: address):
  """
  @dev Set up the GovNFTFactory contract
  """
  self.factory = IGovNFTFactory(_factory)

@external
@view
def collections() -> DynArray[Collection, MAX_COLLECTIONS]:
  """
  @notice Returns all GovNFT collections created by the factory
  @return Array of Collection structs
  """
  collections: DynArray[Collection, MAX_COLLECTIONS] = empty(DynArray[Collection, MAX_COLLECTIONS])
  implementations: DynArray[address, MAX_COLLECTIONS] = self.factory.govNFTs()

  for index in range(0, MAX_COLLECTIONS):
    if index >= len(implementations):
      break
    
    nft: IGovNFT = IGovNFT(implementations[index])

    collections.append(
      Collection({
        address: implementations[index],
        owner: nft.owner(),
        name: nft.name(),
        symbol: nft.symbol(),
        supply: nft.totalSupply()
      })
    )
  return collections

@external
@view
def owned(_account: address, _collection: address) -> DynArray[GovNft, MAX_RESULTS]:
  """
  @notice Returns all owned GovNFTs for the given account and collection
  @return Array of GovNft structs
  """
  return self._owned(_account, _collection)

@internal
@view
def _owned(_account: address, _collection: address) -> DynArray[GovNft, MAX_RESULTS]:
  """
  @notice Returns all owned GovNFTs for the given account and collection
  @return Array of GovNft structs
  """
  govnfts: DynArray[GovNft, MAX_RESULTS] = empty(DynArray[GovNft, MAX_RESULTS])
  
  nft: IGovNFT = IGovNFT(_collection)
  govnft_balance: uint256 = nft.balanceOf(_account)

  for govnft_index in range(0, MAX_NFTS):
    if govnft_index == govnft_balance:
      break
    govnft_id: uint256 = nft.tokenOfOwnerByIndex(_account, govnft_index)

    govnft: GovNft = self._byId(govnft_id, _collection)
    govnfts.append(govnft)

  return govnfts

@external
@view
def minted(_account: address, _collection: address) -> DynArray[GovNft, MAX_RESULTS]:
  """
  @notice Returns all minted GovNFTs for the given account and collection
  @return Array of GovNft structs
  """
  return self._minted(_account, _collection)

@internal
@view
def _minted(_account: address, _collection: address) -> DynArray[GovNft, MAX_RESULTS]:
  """
  @notice Returns all minted GovNFTs for the given account and collection
  @return Array of GovNft structs
  """
  govnfts: DynArray[GovNft, MAX_RESULTS] = empty(DynArray[GovNft, MAX_RESULTS])

  nft: IGovNFT = IGovNFT(_collection)
  supply: uint256 = nft.totalSupply()

  for govnft_id in range(1, MAX_NFTS):
    if govnft_id > supply:
      break
    lock: Lock = nft.locks(govnft_id)

    if lock.minter == _account:
      govnft: GovNft = self._byId(govnft_id, _collection)
      govnfts.append(govnft)

  return govnfts

@external
@view
def byId(_govnft_id: uint256, _collection: address) -> GovNft:
  """
  @notice Returns GovNFT data based on ID and collection
  @param _govnft_id The GovNFT ID and collection to look up
  @return GovNft struct
  """
  return self._byId(_govnft_id, _collection)

@internal
@view
def _byId(_govnft_id: uint256, _collection: address) -> GovNft:
  """
  @notice Returns GovNFT data based on ID and collection
  @param _govnft_id The GovNFT ID and collection to look up
  @return GovNft struct
  """
  nft: IGovNFT = IGovNFT(_collection)
  lock: Lock = nft.locks(_govnft_id)

  token_addr: address = lock.token
  delegate: address = self._raw_call_delegates(token_addr, lock.vault)

  return GovNft({
    id: _govnft_id,
    total_locked: lock.total_locked,
    amount: nft.locked(_govnft_id),
    total_claimed: lock.total_claimed,
    claimable: nft.unclaimed(_govnft_id),
    split_count: lock.split_count,
    cliff_length: lock.cliff_length,
    start: lock.start,
    end: lock.end,
    token: token_addr,
    vault: lock.vault,
    minter: lock.minter,
    owner: nft.ownerOf(_govnft_id),
    address: _collection,
    delegated: delegate
  })

@internal
@view
def _raw_call_delegates(_token: address, _account: address) -> address:
  """
  @notice Returns the delegated address if the token supports it, otherwise empty address
  @param _token The token to call
  @param _account The account to check the delegation of
  """
  if self._raw_call(_token, concat(method_id("delegates()"), convert(_account, bytes32))):
    return IToken(_token).delegates(_account)
  return empty(address)

@internal
@view
def _raw_call(_to: address, _data: Bytes[36]) -> bool:
  """
  @notice Returns true if the call was successfull
  @param _to The address to call
  @param _data The data to send
  """
  response: Bytes[32] = raw_call(
      _to,
      _data,
      max_outsize=32,
      gas=100000,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[1]

  return len(response) > 0
