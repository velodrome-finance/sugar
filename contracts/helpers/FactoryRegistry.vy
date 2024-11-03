# SPDX-License-Identifier: BUSL-1.1
# @version ^0.4.0
# @title Sugar Factory Registry
# @author velodrome.finance
# @notice Sugar Factory Registry to keep track of leaf pool factories

MAX_FACTORIES: public(constant(uint256)) = 10

pool_factories: DynArray[address, MAX_FACTORIES]
rewards_factories: DynArray[address, MAX_FACTORIES]
gauge_factories: DynArray[address, MAX_FACTORIES]
init_hashes: DynArray[bytes32, MAX_FACTORIES]

@deploy
def __init__(
    _pool_factories: DynArray[address, MAX_FACTORIES],
    _rewards_factories: DynArray[address, MAX_FACTORIES],
    _gauge_factories: DynArray[address, MAX_FACTORIES],
    _ihashes: DynArray[bytes32, MAX_FACTORIES],
):
    assert len(_pool_factories) == len(_rewards_factories)
    assert len(_pool_factories) == len(_gauge_factories)
    assert len(_pool_factories) == len(_ihashes)

    self.pool_factories = _pool_factories
    self.rewards_factories = _rewards_factories
    self.gauge_factories = _gauge_factories
    self.init_hashes = _ihashes

@external
@view
def poolFactories() -> DynArray[address, MAX_FACTORIES]:
    return self.pool_factories


@external
@view
def initHashToPoolFactory(_factory: address) -> bytes32:
    counted: uint256 = len(self.pool_factories)

    for findex: uint256 in range(0, MAX_FACTORIES):
        if findex >= counted:
            break

        if self.pool_factories[findex] == _factory:
            return self.init_hashes[findex]

    return empty(bytes32)


@external
@view
def factoriesToPoolFactory(_factory: address) -> (address, address):
    counted: uint256 = len(self.pool_factories)

    for findex: uint256 in range(0, MAX_FACTORIES):
        if findex >= counted:
            break

        if self.pool_factories[findex] == _factory:
            return (
                self.rewards_factories[findex],
                self.gauge_factories[findex]
            )

    return (empty(address), empty(address))
