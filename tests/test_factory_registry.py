import os
import pytest

from brownie import accounts, FactoryRegistry, reverts


@pytest.fixture
def factory_registry(FactoryRegistry, accounts):
    # Deploy the contract using the first test account as the owner
    yield FactoryRegistry.at(os.getenv('REGISTRY_34443'))

def test_initial_state(factory_registry):
    assert factory_registry.owner() == "0xd42C7914cF8dc24a1075E29C283C581bd1b0d3D3"


def test_approve(factory_registry, accounts):
    owner = factory_registry.owner()
    non_owner = "0x9999999999999999999999999999999999999999"
    pool_factory = "0x1111111111111111111111111111111111111111"
    pool_factory_count = factory_registry.pool_factory_count()

    # Approve a new pool factory
    factory_registry.approve(pool_factory, {'from': owner})
    assert factory_registry.pool_factory_count() == pool_factory_count + 1
    assert factory_registry.poolFactories(0) == pool_factory
    assert factory_registry.pool_factory_exists(pool_factory)

def test_unapprove(factory_registry, accounts):
    owner = factory_registry.owner()
    pool_factory = "0x1111111111111111111111111111111111111111"
    pool_factory_count = factory_registry.pool_factory_count()

    # Approve a pool factory to set up the state for unapprove
    factory_registry.approve(pool_factory, {'from': owner})
    assert factory_registry.pool_factory_count() == pool_factory_count + 1
    assert factory_registry.pool_factory_exists(pool_factory)

    # Unapprove the pool factory
    factory_registry.unapprove(pool_factory, {'from': owner})
    assert factory_registry.pool_factory_count() == pool_factory_count
    assert not factory_registry.pool_factory_exists(pool_factory)

def test_factories_to_pool_factory(factory_registry):
    pool_factory = "0x1111111111111111111111111111111111111111"
    result = factory_registry.factoriesToPoolFactory(pool_factory)
    assert result == ("0x0000000000000000000000000000000000000000", pool_factory)
