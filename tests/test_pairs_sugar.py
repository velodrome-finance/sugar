import os
import pytest
from collections import namedtuple

from web3.constants import ADDRESS_ZERO


@pytest.fixture
def sugar_contract(PairsSugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield PairsSugar.at(os.getenv('PAIRS_SUGAR_ADDRESS'))


@pytest.fixture
def PairStruct(sugar_contract):
    method_output = sugar_contract.byAddress.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('PairStruct', members)


@pytest.fixture
def PairEpochStruct(sugar_contract):
    method_output = sugar_contract.epochsByAddress.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('PairEpochStruct', members)


@pytest.fixture
def PairEpochBribeStruct(sugar_contract):
    pair_epoch_comp = sugar_contract.epochsByAddress.abi['outputs'][0]
    pe_bribe_comp = pair_epoch_comp['components'][3]
    members = list(map(lambda _e: _e['name'], pe_bribe_comp['components']))

    yield namedtuple('PairEpochBribeStruct', members)


def test_initial_state(sugar_contract):
    assert sugar_contract.voter() == os.getenv('VOTER_ADDRESS')
    assert sugar_contract.wrapped_bribe_factory() == \
        os.getenv('WRAPPED_BRIBE_FACTORY')
    assert sugar_contract.pair_factory() is not None


def test_byIndex(sugar_contract, PairStruct):
    pair = PairStruct(*sugar_contract.byIndex(0, ADDRESS_ZERO))

    assert pair is not None
    assert len(pair) == 28
    assert pair.pair_address is not None
    assert pair.gauge != ADDRESS_ZERO


def test_byAddress(sugar_contract, PairStruct):
    second_pair = PairStruct(*sugar_contract.byIndex(1, ADDRESS_ZERO))
    pair = PairStruct(*sugar_contract.byAddress(second_pair[0], ADDRESS_ZERO))

    assert pair is not None
    assert len(pair) == 28
    assert pair.pair_address == second_pair.pair_address
    assert pair.gauge != ADDRESS_ZERO


def test_all(sugar_contract, PairStruct):
    first_pair = PairStruct(*sugar_contract.byIndex(0, ADDRESS_ZERO))
    second_pair = PairStruct(*sugar_contract.byIndex(1, ADDRESS_ZERO))
    pairs = list(map(
        lambda _p: PairStruct(*_p),
        sugar_contract.all(300, 0, ADDRESS_ZERO)
    ))

    assert pairs is not None
    assert len(pairs) > 1

    pair1, pair2 = pairs[0:2]

    assert pair1.pair_address == first_pair.pair_address
    assert pair1.gauge == first_pair.gauge

    assert pair2.pair_address == second_pair.pair_address
    assert pair2.gauge == second_pair.gauge


def test_all_limit_offset(sugar_contract, PairStruct):
    second_pair = PairStruct(*sugar_contract.byIndex(1, ADDRESS_ZERO))
    pairs = list(map(
        lambda _p: PairStruct(*_p),
        sugar_contract.all(1, 1, ADDRESS_ZERO)
    ))

    assert pairs is not None
    assert len(pairs) == 1

    pair1 = pairs[0]

    assert pair1.pair_address == second_pair.pair_address
    assert pair1.pair_address == second_pair.pair_address


def test_epochsByAddress_limit_offset(
        sugar_contract,
        PairStruct,
        PairEpochStruct,
        PairEpochBribeStruct
        ):
    first_pair = PairStruct(*sugar_contract.byIndex(0, ADDRESS_ZERO))
    pair_epochs = list(map(
        lambda _p: PairEpochStruct(*_p),
        sugar_contract.epochsByAddress(100, 0, first_pair.pair_address)
    ))

    assert pair_epochs is not None
    assert len(pair_epochs) > 16

    epoch = pair_epochs[1]
    epoch_bribes = list(map(
        lambda _b: PairEpochBribeStruct(*_b),
        epoch.bribes
    ))

    assert epoch.pair_address == first_pair.pair_address
    assert epoch.votes > 0

    assert len(epoch_bribes) > 0
    assert epoch_bribes[0].amount > 0
