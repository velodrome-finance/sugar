# SPDX-License-Identifier: BUSL-1.1
import os
import pytest
from collections import namedtuple

from web3.constants import ADDRESS_ZERO

CHAIN_ID = os.getenv('CHAIN_ID', 10)


@pytest.fixture
def sugar_contract(LpSugar, accounts):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield LpSugar.at(os.getenv(f'LP_SUGAR_ADDRESS_{CHAIN_ID}'))


@pytest.fixture
def TokenStruct(sugar_contract):
    method_output = sugar_contract.tokens.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('TokenStruct', members)


@pytest.fixture
def LpStruct(sugar_contract):
    method_output = sugar_contract.byIndex.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('LpStruct', members)


@pytest.fixture
def SwapLpStruct(sugar_contract):
    method_output = sugar_contract.forSwaps.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('SwapLpStruct', members)


@pytest.fixture
def PositionStruct(sugar_contract):
    method_output = sugar_contract.positionsByFactory.abi['outputs'][0]
    members = list(map(lambda _e: _e['name'], method_output['components']))

    yield namedtuple('PositionStruct', members)


def test_byIndex(sugar_contract, LpStruct):
    lp = LpStruct(*sugar_contract.byIndex(0))

    assert lp is not None
    assert len(lp) == 28
    assert lp.lp is not None
    assert lp.gauge != ADDRESS_ZERO


def test_forSwaps(sugar_contract, SwapLpStruct, LpStruct):
    first_lp = LpStruct(*sugar_contract.byIndex(0))
    second_lp = LpStruct(*sugar_contract.byIndex(1))
    swap_lps = list(map(
        lambda _p: SwapLpStruct(*_p),
        sugar_contract.forSwaps(10, 0)
    ))

    assert swap_lps is not None
    assert len(swap_lps) > 1

    lps = list(map(lambda lp: lp.lp, swap_lps))

    assert first_lp.lp in lps
    assert second_lp.lp in lps


def test_tokens(sugar_contract, TokenStruct, LpStruct):
    first_lp = LpStruct(*sugar_contract.byIndex(0))
    tokens = list(map(
        lambda _p: TokenStruct(*_p),
        sugar_contract.tokens(10, 0, ADDRESS_ZERO, [])
    ))

    assert tokens is not None
    assert len(tokens) > 1

    token0, token1 = tokens[0: 2]

    assert token0.token_address == first_lp.token0
    assert token0.symbol is not None
    assert token0.decimals > 0

    assert token1.token_address == first_lp.token1


def test_all(sugar_contract, LpStruct):
    first_lp = LpStruct(*sugar_contract.byIndex(0))
    second_lp = LpStruct(*sugar_contract.byIndex(1))
    lps = list(map(
        lambda _p: LpStruct(*_p),
        sugar_contract.all(10, 0)
    ))

    assert lps is not None
    assert len(lps) > 1

    lp1, lp2 = lps[0:2]

    assert lp1.lp == first_lp.lp
    assert lp1.gauge == first_lp.gauge

    assert lp2.lp == second_lp.lp
    assert lp2.gauge == second_lp.gauge


def test_all_pagination(sugar_contract, LpStruct):
    max_lps = sugar_contract.MAX_LPS()

    for i in range(0, max_lps, max_lps):
        lps = sugar_contract.all(max_lps, 0)

        assert lps is not None
        assert len(lps) > max_lps - 1


def test_all_limit_offset(sugar_contract, LpStruct):
    second_lp = LpStruct(*sugar_contract.byIndex(1))
    lps = list(map(
        lambda _p: LpStruct(*_p),
        sugar_contract.all(1, 1)
    ))

    assert lps is not None
    assert len(lps) == 1

    lp1 = lps[0]

    assert lp1.lp == second_lp.lp
    assert lp1.lp == second_lp.lp


def test_positions(sugar_contract, PositionStruct):
    limit = 100
    offset = 0
    account = os.getenv(f'TEST_ADDRESS_{CHAIN_ID}')

    positions = list(map(
        lambda _p: PositionStruct(*_p),
        sugar_contract.positions(limit, offset, account)
    ))

    assert positions is not None
    assert len(positions) > 0

    pos = positions[0]

    assert pos.id is not None
    assert pos.lp is not None


def test_positionsUnstakedConcentrated(sugar_contract, PositionStruct):
    limit = 100
    offset = 0
    account = os.getenv(f'TEST_ADDRESS_{CHAIN_ID}')
    is_root_chain = int(CHAIN_ID) in [10, 8453]

    positions = list(map(
        lambda _p: PositionStruct(*_p),
        sugar_contract.positionsUnstakedConcentrated(limit, offset, account)
    ))

    assert positions is not None

    if not is_root_chain:
        assert len(positions) > 0
        return

    assert len(positions) > 0

    pos = positions[0]

    assert pos.id is not None
    assert pos.lp is not None


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_positions_ALM(sugar_contract, PositionStruct):
    account = os.getenv(f'TEST_ALM_ADDRESS_{CHAIN_ID}')

    positions = list(map(
        lambda _p: PositionStruct(*_p),
        sugar_contract.positions(1000, 0, account)
    ))

    assert positions is not None
    assert len(positions) > 0

    pos = positions[0]

    assert pos.id is not None
    assert pos.lp is not None
    assert pos.alm is not None
