import os
import pytest


@pytest.fixture
def sugar_contract(Sugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield Sugar.at('SUGAR_ADDRESS')


def test_initial_state(sugar_contract):
    assert sugar_contract.voter == os.getenv('VOTER_ADDRESS')
    assert sugar_contract.wrapped_bribe_factory == \
        os.getenv('WRAPPED_BRIBE_FACTORY')
    assert sugar_contract.pair_factory is not None


def test_pairByIndex(sugar_contract):
    assert sugar_contract.pairByIndex(0) is not None
