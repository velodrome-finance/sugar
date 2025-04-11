# SPDX-License-Identifier: BUSL-1.1
import os
import pytest

from web3.constants import ADDRESS_ZERO

CHAIN_ID = os.getenv("CHAIN_ID", 10)


@pytest.fixture
def sugar_contract(project):
    # Since we depend on the rest of the protocol,
    # we just point to an existing deployment
    yield project.LpSugar.at(os.getenv(f"LP_SUGAR_ADDRESS_{CHAIN_ID}"))


def test_byIndex(sugar_contract):
    lp = sugar_contract.byIndex(0)

    assert lp is not None
    assert len(lp) == 28
    assert lp.lp is not None


@pytest.mark.skipif(int(CHAIN_ID) not in [10], reason="Only OP")
def test_byAddress(sugar_contract):
    lp = sugar_contract.byAddress("0x8134A2fDC127549480865fB8E5A9E8A8a95a54c5")

    assert lp is not None
    assert len(lp) == 28
    assert lp.lp is not None
    assert lp.gauge != ADDRESS_ZERO
    assert lp.symbol == "vAMMV2-USDC/VELO"


def test_forSwaps(sugar_contract):
    index_lp = sugar_contract.byIndex(1)
    swap_lps = sugar_contract.forSwaps(10, 0)

    assert swap_lps is not None
    assert len(swap_lps) > 1

    lps = list(map(lambda lp: lp.lp, swap_lps))

    assert index_lp.lp in lps


def test_tokens(sugar_contract):
    first_lp = sugar_contract.byIndex(0)
    tokens = sugar_contract.tokens(10, 0, ADDRESS_ZERO, [])

    assert tokens is not None
    assert len(tokens) > 1

    token0, token1 = tokens[0:2]

    assert token0.token_address == first_lp.token0
    assert token0.symbol is not None
    assert token0.decimals > 0

    assert token1.token_address == first_lp.token1


@pytest.mark.skipif(int(CHAIN_ID) not in [10], reason="Only OP")
def test_tokens_long_symbol(sugar_contract):
    tokens = sugar_contract.tokens(1, 995, ADDRESS_ZERO, [])

    assert tokens is not None
    assert len(tokens) > 1

    token = tokens[0]

    assert token.symbol is not None
    assert token.symbol == "-???-"


@pytest.mark.skipif(int(CHAIN_ID) not in [10], reason="Only OP")
def test_tokens_invalid_erc20(sugar_contract):
    tokens = sugar_contract.tokens(2, 0, ADDRESS_ZERO, [ADDRESS_ZERO])

    assert tokens is not None
    assert len(tokens) > 1

    token_addresses = list(map(lambda t: t.token_address, tokens))
    token_symbols = list(map(lambda t: t.symbol, tokens))

    assert ADDRESS_ZERO not in token_addresses
    assert "-???-" not in token_symbols


@pytest.mark.skipif(int(CHAIN_ID) not in [8453], reason="Only BASE")
def test_tokens_max_long_symbol(sugar_contract):
    tokens = sugar_contract.tokens(1, 2508, ADDRESS_ZERO, [])

    assert tokens is not None
    assert len(tokens) > 1

    token = tokens[0]

    assert token.symbol is not None
    assert token.symbol != "-???-"


@pytest.mark.skipif(int(CHAIN_ID) not in [10], reason="Only OP")
def test_all_long_symbol(sugar_contract):
    pools = sugar_contract.all(1, 995)

    assert pools is not None
    assert len(pools) == 1

    pool = pools[0]

    assert pool.symbol is not None
    assert pool.symbol == "-???-"


def test_all(sugar_contract):
    first_lp = sugar_contract.byIndex(0)
    second_lp = sugar_contract.byIndex(1)
    lps = sugar_contract.all(10, 0)

    assert lps is not None
    assert len(lps) > 1

    lp1, lp2 = lps[0:2]

    assert lp1.lp == first_lp.lp
    assert lp1.gauge == first_lp.gauge

    assert lp2.lp == second_lp.lp
    assert lp2.gauge == second_lp.gauge

    # check we calculate the root pool address
    if int(CHAIN_ID) == 34443:
        assert lp1.root == "0x2bb4CFF1FE3F56599b4D409B2498B96D3E3f6665"
        assert lp2.root == "0x48a3Ed8552483ed31Fd87ECa1a7b2F94aa1Cc394"


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_all_pagination(sugar_contract):
    max_lps = sugar_contract.MAX_LPS()

    for i in range(0, max_lps, max_lps):
        lps = sugar_contract.all(max_lps, 0)

        assert lps is not None
        assert len(lps) > max_lps - 1


def test_all_limit_offset(sugar_contract):
    second_lp = sugar_contract.byIndex(1)
    lps = sugar_contract.all(1, 1)

    assert lps is not None
    assert len(lps) == 1

    lp1 = lps[0]

    assert lp1.lp == second_lp.lp
    assert lp1.lp == second_lp.lp


def test_positions(sugar_contract):
    limit = 100
    offset = 0
    account = os.getenv(f"TEST_ADDRESS_{CHAIN_ID}")

    positions = sugar_contract.positions(limit, offset, account)

    assert positions is not None
    assert len(positions) > 0

    pos = positions[0]

    assert pos.id is not None
    assert pos.lp is not None


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_positionsUnstakedConcentrated(sugar_contract):
    limit = 100
    offset = 0
    account = os.getenv(f"TEST_ADDRESS_{CHAIN_ID}")

    positions = sugar_contract.positionsUnstakedConcentrated(limit, offset, account)

    assert positions is not None
    assert len(positions) > 0

    pos = positions[0]

    assert pos.id is not None
    assert pos.lp is not None


@pytest.mark.skipif(int(CHAIN_ID) not in [10, 8453], reason="Only root chains")
def test_positions_ALM(sugar_contract):
    account = os.getenv(f"TEST_ALM_ADDRESS_{CHAIN_ID}")

    positions = sugar_contract.positions(1000, 0, account)

    assert positions is not None
    assert len(positions) > 0

    pos = positions[0]

    assert pos.id is not None
    assert pos.lp is not None
    assert pos.alm is not None
