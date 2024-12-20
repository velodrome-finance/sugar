# SPDX-License-Identifier: BUSL-1.1
import os
import pytest

CHAIN_ID = os.getenv("CHAIN_ID", 10)


@pytest.fixture
def sugar_contract(project, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield project.RewardsSugar.at(os.getenv(f"REWARDS_SUGAR_ADDRESS_{CHAIN_ID}"))


@pytest.fixture
def lp_sugar_contract(project, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield project.LpSugar.at(os.getenv(f"LP_SUGAR_ADDRESS_{CHAIN_ID}"))


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_epochsByAddress_limit_offset(sugar_contract, lp_sugar_contract):
    first_lp = lp_sugar_contract.byIndex(1)
    lp_epochs = sugar_contract.epochsByAddress(20, 3, first_lp.lp)

    assert lp_epochs is not None
    assert len(lp_epochs) > 10

    epoch = lp_epochs[1]

    assert epoch.lp == first_lp.lp
    assert epoch.votes > 0
    assert epoch.emissions > 0

    if len(epoch.bribes) > 0:
        assert epoch.bribes[0].amount > 0

    if len(epoch.fees) > 0:
        assert epoch.fees[0].amount > 0


def test_epochsLatest_limit_offset(sugar_contract, lp_sugar_contract):
    second_lp = lp_sugar_contract.byIndex(1)
    lp_epoch = sugar_contract.epochsByAddress(1, 0, second_lp.lp)
    latest_epoch = sugar_contract.epochsLatest(1, 1)

    assert lp_epoch is not None

    # Ignore new fresh new releases...
    if len(latest_epoch) < 1:
        return

    pepoch = lp_epoch[0]
    lepoch = latest_epoch[0]

    assert lepoch.lp == pepoch.lp
    assert lepoch.ts == pepoch.ts


@pytest.mark.skipif(int(CHAIN_ID) not in [10], reason="Only Optimism")
def test_forRoot(sugar_contract, lp_sugar_contract):
    first_lp = lp_sugar_contract.byIndex(1)

    # Use `lp` instead of `root` for testing
    addresses = sugar_contract.forRoot(first_lp.lp)

    assert addresses is not None

    assert len(addresses) == 3
    assert addresses[0] == first_lp.gauge
    assert addresses[1] == first_lp.fee
    assert addresses[2] == first_lp.bribe
