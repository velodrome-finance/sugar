import os
import pytest

from web3.constants import ADDRESS_ZERO


@pytest.fixture
def factory_registry(FactoryRegistry):
    # Deploy the contract using the first test account as the owner
    yield FactoryRegistry.at(os.getenv('REGISTRY_34443'))


def test_initial_state(factory_registry):
    assert factory_registry.owner() ==\
      "0xd42C7914cF8dc24a1075E29C283C581bd1b0d3D3"


def test_factories_to_pool_factory(factory_registry):
    pool_factory = "0x1111111111111111111111111111111111111111"
    result = factory_registry.factoriesToPoolFactory(pool_factory)
    assert result == [ADDRESS_ZERO, pool_factory]
