import os
import pytest

@pytest.fixture
def sugar_contract(Sugar, accounts):
    yield Sugar.deploy(
        os.getenv('VOTER_ADDRESS'),
        os.getenv('WRAPPED_BRIBE_FACTORY'),
        {'from': accounts[0]}
    )


def test_initial_state(sugar_contract):
    assert sugar_contract.voter == os.getenv('VOTER_ADDRESS')
    assert sugar_contract.wrapped_bribe_factory == \
        os.getenv('WRAPPED_BRIBE_FACTORY')
    assert sugar_contract.pair_factory is not None


def test_pairByIndex(sugar_contract):
    assert sugar_contract.pairByIndex(0) is not None
