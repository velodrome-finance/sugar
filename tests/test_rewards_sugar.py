# SPDX-License-Identifier: BUSL-1.1
import os
import pytest
from collections import namedtuple

CHAIN_ID = os.getenv('CHAIN_ID', 10)


@pytest.fixture
def sugar_contract(RewardsSugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield RewardsSugar.at(os.getenv(f'REWARDS_SUGAR_ADDRESS_{CHAIN_ID}'))


@pytest.fixture
def lp_sugar_contract(LpSugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield LpSugar.at(os.getenv(f'LP_SUGAR_ADDRESS_{CHAIN_ID}'))


@pytest.fixture
def LpStruct(lp_sugar_contract):
    method_output = lp_sugar_contract.byIndex.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('LpStruct', members)


@pytest.fixture
def LpEpochStruct(sugar_contract):
    method_output = sugar_contract.epochsByAddress.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('LpEpochStruct', members)


@pytest.fixture
def LpEpochBribeStruct(sugar_contract):
    lp_epoch_comp = sugar_contract.epochsByAddress.abi['outputs'][0]
    pe_bribe_comp = lp_epoch_comp['components'][4]
    members = list(map(lambda _e: _e['name'], pe_bribe_comp['components']))

    yield namedtuple('LpEpochBribeStruct', members)


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_epochsByAddress_limit_offset(
    sugar_contract,
    lp_sugar_contract,
    LpStruct,
    LpEpochStruct,
    LpEpochBribeStruct
):
    first_lp = LpStruct(*lp_sugar_contract.byIndex(1))
    lp_epochs = list(map(
        lambda _p: LpEpochStruct(*_p),
        sugar_contract.epochsByAddress(20, 3, first_lp.lp)
    ))

    assert lp_epochs is not None
    assert len(lp_epochs) > 10

    epoch = lp_epochs[1]
    epoch_bribes = list(map(
        lambda _b: LpEpochBribeStruct(*_b),
        epoch.bribes
    ))
    epoch_fees = list(map(
        lambda _f: LpEpochBribeStruct(*_f),
        epoch.fees
    ))

    assert epoch.lp == first_lp.lp
    assert epoch.votes > 0
    assert epoch.emissions > 0

    if len(epoch_bribes) > 0:
        assert epoch_bribes[0].amount > 0

    if len(epoch_fees) > 0:
        assert epoch_fees[0].amount > 0


def test_epochsLatest_limit_offset(
    sugar_contract,
    lp_sugar_contract,
    LpStruct,
    LpEpochStruct
):
    second_lp = LpStruct(*lp_sugar_contract.byIndex(1))
    lp_epoch = list(map(
        lambda _p: LpEpochStruct(*_p),
        sugar_contract.epochsByAddress(1, 0, second_lp.lp)
    ))
    latest_epoch = list(map(
        lambda _p: LpEpochStruct(*_p),
        sugar_contract.epochsLatest(1, 1)
    ))

    assert lp_epoch is not None

    # Ignore new fresh new releases...
    if len(latest_epoch) < 1:
        return

    pepoch = LpEpochStruct(*lp_epoch[0])
    lepoch = LpEpochStruct(*latest_epoch[0])

    assert lepoch.lp == pepoch.lp
    assert lepoch.ts == pepoch.ts


@pytest.mark.skipif(int(CHAIN_ID) not in [10], reason="Only Optimism")
def test_forRoot(sugar_contract, lp_sugar_contract, LpStruct):
    first_lp = LpStruct(*lp_sugar_contract.byIndex(1))

    # Use `lp` instead of `root` for testing
    addresses = sugar_contract.forRoot(first_lp.lp)

    assert addresses is not None

    assert len(addresses) == 3
    assert addresses[0] == first_lp.gauge
    assert addresses[1] == first_lp.fee
    assert addresses[2] == first_lp.bribe
