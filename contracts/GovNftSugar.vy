# SPDX-License-Identifier: BUSL-1.1
# @version >=0.3.6 <0.4.0

# @title GovNFT Sugar
# @author ZoomerAnon
# @notice Makes it nicer to work with GovNFTs.

# Constants

MAX_RESULTS: constant(uint256) = 300
MAX_NFTS: constant(uint256) = 2000

# Structs

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

# Contracts / Interfaces

interface IGovNFT:
  def balanceOf(_account: address) -> uint256: view
  def tokenOfOwnerByIndex(_account: address, _index: uint256) -> uint256: view
  def totalSupply() -> uint256: view
  def ownerOf(_govnft_id: uint256) -> address: view
  def locks(_govnft_id: uint256) -> Lock: view
  def unclaimed(_govnft_id: uint256) -> uint256: view
  def locked(_govnft_id: uint256) -> uint256: view

interface IToken:
  def delegates(_account: address) -> address: view

# Vars
nft: public(IGovNFT)

# Methods

@external
def __init__(_nft: address):
  """
  @dev Set up the GovNFT contract
  """
  self.nft = IGovNFT(_nft)

@external
@view
def owned(_account: address) -> DynArray[GovNft, MAX_RESULTS]:
  """
  @notice Returns all owned GovNFTs for the given account
  @return Array of GovNft structs
  """
  return self._owned(_account)

@internal
@view
def _owned(_account: address) -> DynArray[GovNft, MAX_RESULTS]:
  """
  @notice Returns all owned GovNFTs for the given account
  @return Array of GovNft structs
  """
  govnfts: DynArray[GovNft, MAX_RESULTS] = empty(DynArray[GovNft, MAX_RESULTS])
  
  govnft_balance: uint256 = self.nft.balanceOf(_account)

  for govnft_index in range(0, MAX_NFTS):
    if govnft_index == govnft_balance:
      break
    govnft_id: uint256 = self.nft.tokenOfOwnerByIndex(_account, govnft_index)

    govnft: GovNft = self._byId(govnft_id)
    govnfts.append(govnft)

  return govnfts

@external
@view
def minted(_account: address) -> DynArray[GovNft, MAX_RESULTS]:
  """
  @notice Returns all minted GovNFTs for the given account
  @return Array of GovNft structs
  """
  return self._minted(_account)

@internal
@view
def _minted(_account: address) -> DynArray[GovNft, MAX_RESULTS]:
  """
  @notice Returns all minted GovNFTs for the given account
  @return Array of GovNft structs
  """
  govnfts: DynArray[GovNft, MAX_RESULTS] = empty(DynArray[GovNft, MAX_RESULTS])

  supply: uint256 = self.nft.totalSupply()

  for govnft_id in range(1, MAX_NFTS):
    if govnft_id > supply:
      break
    lock: Lock = self.nft.locks(govnft_id)

    if lock.minter == _account:
      govnft: GovNft = self._byId(govnft_id)
      govnfts.append(govnft)

  return govnfts

@external
@view
def byId(_govnft_id: uint256) -> GovNft:
  """
  @notice Returns GovNFT data based on ID
  @param _govnft_id The GovNFT ID to look up
  @return GovNft struct
  """
  return self._byId(_govnft_id)

@internal
@view
def _byId(_govnft_id: uint256) -> GovNft:
  """
  @notice Returns GovNFT data based on ID
  @param _govnft_id The GovNFT ID to look up
  @return GovNft struct
  """

  lock: Lock = self.nft.locks(_govnft_id)

  token_addr: address = lock.token
  token: IToken = IToken(token_addr)

  return GovNft({
    id: _govnft_id,
    total_locked: lock.total_locked,
    amount: self.nft.locked(_govnft_id),
    total_claimed: lock.total_claimed,
    claimable: self.nft.unclaimed(_govnft_id),
    split_count: lock.split_count,
    cliff_length: lock.cliff_length,
    start: lock.start,
    end: lock.end,
    token: token_addr,
    vault: lock.vault,
    minter: lock.minter,
    owner: self.nft.ownerOf(_govnft_id),
    address: self.nft.address,
    delegated: token.delegates(lock.vault)
  })
