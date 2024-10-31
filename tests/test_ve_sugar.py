# SPDX-License-Identifier: BUSL-1.1
import os
import pytest

from collections import namedtuple

CHAIN_ID = os.getenv('CHAIN_ID', 10)


@pytest.fixture
@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def sugar_contract(VeSugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield VeSugar.at(os.getenv(f'VE_SUGAR_ADDRESS_{CHAIN_ID}'))


@pytest.fixture
@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def VeNFTStruct(sugar_contract):
    method_output = sugar_contract.byId.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('VeNFTStruct', members)


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_initial_state(sugar_contract):
    assert sugar_contract.voter() == os.getenv(f'VOTER_{CHAIN_ID}')
    assert sugar_contract.dist() == \
        os.getenv(f'DIST_{CHAIN_ID}')
    assert sugar_contract.ve() is not None


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_byId(sugar_contract, VeNFTStruct):
    venft = VeNFTStruct(*sugar_contract.byId(1))

    assert venft is not None
    assert len(venft) == 14
    assert venft.id is not None
    assert venft.voted_at > 0


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_byAccount(sugar_contract, VeNFTStruct):
    venft = VeNFTStruct(*sugar_contract.byId(1))
    acc_venft = list(map(
        lambda _v: VeNFTStruct(*_v),
        sugar_contract.byAccount(venft.account)
    ))

    assert venft is not None
    assert len(venft) == 14
    assert venft.account == acc_venft[0].account


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_all(sugar_contract, VeNFTStruct):
    first_venft = VeNFTStruct(*sugar_contract.byId(1))
    second_venft = VeNFTStruct(*sugar_contract.byId(2))
    venfts = list(map(
        lambda _v: VeNFTStruct(*_v),
        sugar_contract.all(30, 0)
    ))

    assert venfts is not None
    assert len(venfts) > 2

    venft1, venft2 = venfts[0:2]

    assert venft1.id == first_venft.id
    assert venft1.account == first_venft.account

    assert venft2.id == second_venft.id
    assert venft2.account == second_venft.account


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_all_limit_offset(sugar_contract, VeNFTStruct):
    second_venft = VeNFTStruct(*sugar_contract.byId(1))
    venfts = list(map(
        lambda _v: VeNFTStruct(*_v),
        sugar_contract.all(1, 1)
    ))

    assert venfts is not None
    assert len(venfts) == 1

    venft1 = venfts[0]

    assert venft1.id == second_venft.id
    assert venft1.account == second_venft.account
