import os
import pytest
from web3.constants import ADDRESS_ZERO


@pytest.fixture
def sugar_contract(Sugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield Sugar.at(os.getenv('SUGAR_ADDRESS'))


def test_initial_state(sugar_contract):
    assert sugar_contract.voter() == os.getenv('VOTER_ADDRESS')
    assert sugar_contract.wrapped_bribe_factory() == \
        os.getenv('WRAPPED_BRIBE_FACTORY')
    assert sugar_contract.pair_factory() is not None


def test_pairByIndex(sugar_contract):
    pair = sugar_contract.pairByIndex(0)

    assert pair is not None
    assert len(pair) == 20
    assert pair[0] is not None
    # No gauge
    assert pair[13] == ADDRESS_ZERO


def test_pairByAddress(sugar_contract):
    second_pair = sugar_contract.pairByIndex(1)
    pair = sugar_contract.pairByAddress(second_pair[0])

    assert pair is not None
    assert len(pair) == 20
    assert pair[0] == second_pair[0]
    # Gauge found
    assert pair[12] != ADDRESS_ZERO


def test_pairs(sugar_contract):
    first_pair = sugar_contract.pairByIndex(0)
    second_pair = sugar_contract.pairByIndex(1)
    pairs = sugar_contract.pairs(200, 0)

    assert pairs is not None
    assert len(pairs) > 1

    pair1, pair2 = pairs[0:2]

    assert pair1[0] == first_pair[0]
    assert pair1[12] == first_pair[12]

    assert pair2[0] == second_pair[0]
    assert pair2[12] == second_pair[12]


def test_pairs_limit_offset(sugar_contract):
    second_pair = sugar_contract.pairByIndex(1)
    pairs = sugar_contract.pairs(1, 1)

    assert pairs is not None
    assert len(pairs) == 1

    pair1 = pairs[0]

    assert pair1[0] == second_pair[0]
    assert pair1[12] == second_pair[12]
