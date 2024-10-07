# SPDX-License-Identifier: BUSL-1.1
# @version ^0.3.10
# @title Sugar Factory Registry
# @author velodrome.finance
# @notice Sugar Factory Registry to keep track of leaf pool factories

MAX_FACTORIES: public(constant(uint256)) = 10

owner: public(address)
pool_factories: public(DynArray[address, MAX_FACTORIES])
pool_factory_exists: public(HashMap[address, bool])

@external
def __init__(_owner: address):
    self.owner = _owner

@internal
def _only_owner():
    assert msg.sender == self.owner, "Ownable: caller is not the owner"

@external
def approve(pool_factory: address):
    self._only_owner()
    
    if self.pool_factory_exists[pool_factory]:
        raise "Already exists"
    
    self.pool_factories.append(pool_factory)
    self.pool_factory_exists[pool_factory] = True

@external
def unapprove(pool_factory: address):
    self._only_owner()
    
    if self.pool_factory_exists[pool_factory] == False:
        raise "Not exists"

    for i in range(MAX_FACTORIES):
        if self.pool_factories[i] == pool_factory:
            self.pool_factories[i] = self.pool_factories[len(self.pool_factories) - 1]
            self.pool_factories.pop()
            break

    self.pool_factory_exists[pool_factory] = False

@external
@view
def factoriesToPoolFactory(poolFactory: address) -> (address, address):
    return (empty(address), poolFactory)

@external
@view
def poolFactories() -> DynArray[address, MAX_FACTORIES]:
    return self.pool_factories
