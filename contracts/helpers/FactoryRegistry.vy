# SPDX-License-Identifier: BUSL-1.1
# @version ^0.3.10
# @title Sugar Factory Registry
# @author velodrome.finance
# @notice Sugar Factory Registry to keep track of leaf pool factories


MAX_FACTORIES: public(constant(uint256)) = 10

owner: public(address)
poolFactories: public(DynArray[address, MAX_FACTORIES]) # camelCase to have same signature as origin registry

pool_factory_count: uint256
pool_factory_exists: HashMap[address, bool]

@external
def __init__(_owner: address):
    self.owner = _owner
    self.pool_factory_count = 0

@internal
def _only_owner():
    assert msg.sender == self.owner, "Ownable: caller is not the owner"

@external
def approve(pool_factory: address):
    self._only_owner()
    
    # Check if already present
    if self.pool_factory_exists[pool_factory]:
        raise "Already exists"
    
    # Add the poolFactory to the list
    self.poolFactories[self.pool_factory_count] = pool_factory
    self.pool_factory_count += 1
    self.pool_factory_exists[pool_factory] = True

@external
def unapprove(pool_factory: address):
    self._only_owner()
    
    if self.pool_factory_exists[pool_factory] == False:
        raise "Not exists"

    for i in range(MAX_FACTORIES):
        if self.poolFactories[i] == pool_factory:
            # Remove the pool_factory by shifting elements
            for j in range(0, MAX_FACTORIES):
                if j < i: continue
                if j >= self.pool_factory_count: break
                self.poolFactories[j] = self.poolFactories[j + 1]
            self.pool_factory_count -= 1
            break

    self.pool_factory_exists[pool_factory] = False

@external
@view
def factoriesToPoolFactory(poolFactory: address) -> (address, address):
    return (empty(address), poolFactory)
