import os
import pytest

from web3.constants import ADDRESS_ZERO

CHAIN_ID = os.getenv('CHAIN_ID', 34443)


@pytest.fixture
@pytest.mark.skipif(int(CHAIN_ID) in [10, 8453], reason="Only leaf chains")
def factory_registry(FactoryRegistry):
    # Deploy the contract using the first test account as the owner
    yield FactoryRegistry.at(os.getenv(f'REGISTRY_{CHAIN_ID}'))


@pytest.mark.skipif(int(CHAIN_ID) in [10, 8453], reason="Only leaf chains")
def test_poolFactories(factory_registry):
    factories = factory_registry.poolFactories()
    assert len(factories) > 0


@pytest.mark.skipif(int(CHAIN_ID) in [10, 8453], reason="Only leaf chains")
def test_factoriesToPoolFactory(factory_registry):
    factories = factory_registry.poolFactories()
    result = factory_registry.factoriesToPoolFactory(factories[0])
    assert ADDRESS_ZERO not in result

    result = factory_registry.factoriesToPoolFactory(ADDRESS_ZERO)
    assert ADDRESS_ZERO in result


@pytest.mark.skipif(int(CHAIN_ID) in [10, 8453], reason="Only leaf chains")
def test_initHashToPoolFactory(factory_registry):
    factories = factory_registry.poolFactories()
    result = factory_registry.initHashToPoolFactory(factories[0])

    assert str(result) in os.getenv(f'INIT_HASHES_{CHAIN_ID}')
