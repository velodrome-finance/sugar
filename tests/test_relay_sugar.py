# SPDX-License-Identifier: BUSL-1.1
import os
import pytest

from collections import namedtuple
from web3.constants import ADDRESS_ZERO

CHAIN_ID = os.getenv('CHAIN_ID', 10)


@pytest.fixture
def sugar_contract(RelaySugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield RelaySugar.at(os.getenv(f'RELAY_SUGAR_ADDRESS_{CHAIN_ID}'))


@pytest.fixture
def RelayStruct(sugar_contract):
    method_output = sugar_contract.all.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('RelayStruct', members)


def test_initial_state(sugar_contract):
    assert sugar_contract.voter() == os.getenv(f'VOTER_{CHAIN_ID}')
    assert sugar_contract.registries(0) == \
        os.getenv(f'RELAY_REGISTRY_ADDRESSES_{CHAIN_ID}').split(',')[0]
    assert sugar_contract.ve() is not None
    assert sugar_contract.token() is not None


def test_all(sugar_contract, RelayStruct):
    relays = list(map(
        lambda _r: RelayStruct(*_r),
        sugar_contract.all(ADDRESS_ZERO)
    ))

    assert len(relays) > 5
