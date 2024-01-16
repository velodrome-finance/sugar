# SPDX-License-Identifier: BUSL-1.1
import os
import pytest

from collections import namedtuple
from web3.constants import ADDRESS_ZERO


@pytest.fixture
def sugar_contract(RelaySugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield RelaySugar.at(os.getenv('RELAY_SUGAR_ADDRESS'))


@pytest.fixture
def RelayStruct(sugar_contract):
    method_output = sugar_contract.all.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('RelayStruct', members)


def test_initial_state(sugar_contract):
    assert sugar_contract.voter() == os.getenv('VOTER_ADDRESS')
    assert sugar_contract.registries(0) == os.getenv('RELAY_REGISTRY_ADDRESS')
    assert sugar_contract.ve() is not None
    assert sugar_contract.token() is not None


def test_all(sugar_contract, RelayStruct):
    relays = list(map(
        lambda _r: RelayStruct(*_r),
        sugar_contract.all(ADDRESS_ZERO)
    ))

    assert len(relays) > 5
