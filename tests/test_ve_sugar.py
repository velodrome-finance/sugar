import os
import pytest
from web3.constants import ADDRESS_ZERO


@pytest.fixture
def sugar_contract(VeSugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield VeSugar.at(os.getenv('VE_SUGAR_ADDRESS'))


def test_initial_state(sugar_contract):
    assert sugar_contract.voter() == os.getenv('VOTER_ADDRESS')
    assert sugar_contract.rewards_distributor() == \
        os.getenv('REWARDS_DIST_ADDRESS')
    assert sugar_contract.ve() is not None


def test_byId(sugar_contract):
    venft = sugar_contract.byId(1)

    assert venft is not None
    assert len(venft) == 13
    assert venft[0] is not None
    # No votes
    assert len(venft[8]) == 0
    assert len(venft[9]) == 0


def test_byAccount(sugar_contract):
    venft = sugar_contract.byId(1)
    acc_venft = sugar_contract.byAccount(venft[1])

    assert venft is not None
    assert len(venft) == 13
    assert venft[1] == acc_venft[0][1]


def test_all(sugar_contract):
    first_venft = sugar_contract.byId(1)
    second_venft = sugar_contract.byId(2)
    venfts = sugar_contract.all(1000, 0)

    assert venfts is not None
    assert len(venfts) > 1

    venft1, venft2 = venfts[0:2]

    assert venft1[0] == first_venft[0]
    assert venft1[1] == first_venft[1]

    assert venft2[0] == second_venft[0]
    assert venft2[1] == second_venft[1]


def test_all_limit_offset(sugar_contract):
    second_venft = sugar_contract.byId(1)
    venfts = sugar_contract.all(1, 1)

    assert venfts is not None
    assert len(venfts) == 1

    venft1 = venfts[0]

    assert venft1[0] == second_venft[0]
    assert venft1[1] == second_venft[1]
