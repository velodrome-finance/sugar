# SPDX-License-Identifier: BUSL-1.1
import os
import pytest
from collections import namedtuple

from web3.constants import ADDRESS_ZERO


@pytest.fixture
def sugar_contract(GovNftSugar, accounts):
    # point to an existing deployment
    yield GovNftSugar.at(os.getenv('GOVNFT_SUGAR_ADDRESS'))


@pytest.fixture
def GovNftStruct(sugar_contract):
    method_output = sugar_contract.byId.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('GovNftStruct', members)


@pytest.fixture
def CollectionStruct(sugar_contract):
    method_output = sugar_contract.collections.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('CollectionStruct', members)


def test_initial_state(sugar_contract):
    assert sugar_contract.factory() == os.getenv('GOVNFT_FACTORY_ADDRESS')


def test_byId(sugar_contract, GovNftStruct):
    govnft = GovNftStruct(
        *sugar_contract.byId(1, os.getenv('GOVNFT_COLLECTION_ADDRESS'))
    )

    assert govnft is not None
    assert len() == 15
    assert govnft.minter != ADDRESS_ZERO
    assert govnft.address != ADDRESS_ZERO


def test_collections(sugar_contract, CollectionStruct):
    collections = list(map(
        lambda _p: CollectionStruct(*_p),
        sugar_contract.collections()
    ))

    assert collections is not None
    assert len(collections) > 1
    assert collections[0].address == os.getenv('GOVNFT_COLLECTION_ADDRESS')


def test_owned(sugar_contract, GovNftStruct):
    govnft = GovNftStruct(
        *sugar_contract.byId(1, os.getenv('GOVNFT_COLLECTION_ADDRESS'))
    )

    assert govnft is not None

    owned_govnfts = list(map(
        lambda _p: CollectionStruct(*_p),
        sugar_contract.owned(govnft.owner, govnft.address)
    ))

    assert owned_govnfts is not None
    assert len(owned_govnfts) > 1
    owned_govnft = owned_govnfts[0]

    assert owned_govnft.owner == govnft.owner
    assert owned_govnft.address == govnft.address


def test_minted(sugar_contract, GovNftStruct):
    govnft = GovNftStruct(
        *sugar_contract.byId(1, os.getenv('GOVNFT_COLLECTION_ADDRESS'))
    )

    assert govnft is not None

    minted_govnfts = list(map(
        lambda _p: CollectionStruct(*_p),
        sugar_contract.minted(govnft.owner, govnft.address)
    ))

    assert minted_govnfts is not None
    assert len(minted_govnfts) > 1
    minted_govnft = minted_govnfts[0]

    assert minted_govnft.owner == govnft.owner
    assert minted_govnft.address == govnft.address
