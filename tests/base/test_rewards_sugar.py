# SPDX-License-Identifier: BUSL-1.1
import os
import pytest
from collections import namedtuple

from web3.constants import ADDRESS_ZERO


@pytest.fixture
def sugar_contract(RewardsSugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield LpSugar.at(os.getenv('REWARDS_SUGAR_ADDRESS_8453'))


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


def test_initial_state(sugar_contract):
    assert sugar_contract.voter() == os.getenv('VOTER_8453')
    assert sugar_contract.registry() == os.getenv('REGISTRY_8453')


def test_epochsByAddress_limit_offset(
    sugar_contract,
    LpStruct,
    LpEpochStruct,
    LpEpochBribeStruct
):
    first_lp = LpStruct(*sugar_contract.byIndex(0))
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
    LpStruct,
    LpEpochStruct
):
    second_lp = LpStruct(*sugar_contract.byIndex(1))
    lp_epoch = list(map(
        lambda _p: LpEpochStruct(*_p),
        sugar_contract.epochsByAddress(1, 0, second_lp.lp)
    ))
    latest_epoch = list(map(
        lambda _p: LpEpochStruct(*_p),
        sugar_contract.epochsLatest(1, 1)
    ))

    assert lp_epoch is not None
    assert len(latest_epoch) == 1

    pepoch = LpEpochStruct(*lp_epoch[0])
    lepoch = LpEpochStruct(*latest_epoch[0])

    assert lepoch.lp == pepoch.lp
    assert lepoch.ts == pepoch.ts
