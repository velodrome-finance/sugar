# SPDX-License-Identifier: BUSL-1.1
import os
import pytest

from web3.constants import ADDRESS_ZERO

CHAIN_ID = os.getenv("CHAIN_ID", 10)


@pytest.fixture
@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def sugar_contract(project, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield project.RelaySugar.at(os.getenv(f"RELAY_SUGAR_ADDRESS_{CHAIN_ID}"))


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_initial_state(sugar_contract):
    assert sugar_contract.voter() == os.getenv(f"VOTER_{CHAIN_ID}")
    assert (
        sugar_contract.registries(0)
        == os.getenv(f"RELAY_REGISTRY_ADDRESSES_{CHAIN_ID}").split(",")[0]
    )
    assert sugar_contract.ve() is not None
    assert sugar_contract.token() is not None


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_all(sugar_contract):
    relays = sugar_contract.all(ADDRESS_ZERO)

    assert len(relays) > 5
