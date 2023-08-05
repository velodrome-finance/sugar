# SPDX-License-Identifier: BUSL-1.1
# @version >=0.3.6 <0.4.0

# @title Velodrome Finance Relay Sugar v2
# @author stas, ZoomerAnon
# @notice Makes it nicer to work with autocompounders.

MAX_COMPOUNDERS: constant(uint256) = 50

struct AutoCompounder:
  name: String[100]
  tokenId: uint256
  address: address

interface IAutoCompounderFactory:
  def autoCompounders() -> DynArray[address, MAX_COMPOUNDERS]: view

interface IAutoCompounder:
  def name() -> String[100]: view
  def tokenId() -> uint256: view

# Vars
factory: public(IAutoCompounderFactory)

@external
def __init__(_factory: address):
  """
  @dev Set up our external factory contract
  """
  self.factory = IAutoCompounderFactory(_factory)

@external
@view
def all() -> DynArray[AutoCompounder, MAX_COMPOUNDERS]:
  """
  @notice Returns all AutoCompounders
  @return Array of AutoCompounder structs
  """
  compounders: DynArray[AutoCompounder, MAX_COMPOUNDERS] = empty(DynArray[AutoCompounder, MAX_COMPOUNDERS])
  addresses: DynArray[address, MAX_COMPOUNDERS] = self.factory.autoCompounders()
  
  for index in range(0, len(addresses)):
    autocompounder: IAutoCompounder = IAutoCompounder(addresses[index])

    compounders.append(AutoCompounder({
      name: autocompounder.name(),
      tokenId: autocompounder.tokenId(),
      address: addresses[index]
    }))

  return compounders
