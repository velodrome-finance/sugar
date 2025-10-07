# SPDX-License-Identifier: BUSL-1.1
# @version ^0.4.0

# @title Velodrome Finance Token Sugar
# @author stas, ethzoomer
# @notice Makes it nicer to work with tokens.

from modules import lp_shared

initializes: lp_shared

# Structs

MAX_TOKENS: public(constant(uint256)) = 2000
MAX_TOKEN_SYMBOL_LEN: public(constant(uint256)) = 32

struct Token:
  token_address: address
  symbol: String[MAX_TOKEN_SYMBOL_LEN]
  decimals: uint8
  account_balance: uint256
  listed: bool
  emerging: bool

# Our contracts / Interfaces

interface IPool:
  def token0() -> address: view
  def token1() -> address: view

interface IPoolLauncher:
  def emerging(_pool: address) -> uint256: view
  def isPairableToken(_token: address) -> bool: view

# Vars
v2_launcher: public(IPoolLauncher)
cl_launcher: public(IPoolLauncher)

@deploy
def __init__(_voter: address, _registry: address, _convertor: address,\
    _v2_launcher: address, _cl_launcher: address):
  """
  @dev Sets up our external contract addresses
  """
  self.v2_launcher = IPoolLauncher(_v2_launcher)
  self.cl_launcher = IPoolLauncher(_cl_launcher)

  # Modules...
  lp_shared.__init__(_voter, _registry, _convertor)

@external
@view
def tokens(_limit: uint256, _offset: uint256, _account: address, \
    _addresses: DynArray[address, MAX_TOKENS]) -> DynArray[Token, MAX_TOKENS]:
  """
  @notice Returns a collection of tokens data based on available pools
  @param _limit The max amount of pools to check
  @param _offset The amount of pools to skip
  @param _account The account to check the balances
  @param _addresses Custom tokens to check
  @return Array for Token structs
  """
  pools: DynArray[address[4], lp_shared.MAX_POOLS] = \
    lp_shared._pools(_limit, _offset, empty(address))

  pools_count: uint256 = len(pools)
  addresses_count: uint256 = len(_addresses)
  col: DynArray[Token, MAX_TOKENS] = empty(DynArray[Token, MAX_TOKENS])
  seen: DynArray[address, MAX_TOKENS] = empty(DynArray[address, MAX_TOKENS])

  for index: uint256 in range(0, MAX_TOKENS):
    if index >= addresses_count:
      break

    seen.append(_addresses[index])
    new_token: Token = self._token(_addresses[index], _account, False)

    if new_token.decimals != 0 and new_token.symbol != "":
      col.append(new_token)

  for index: uint256 in range(0, lp_shared.MAX_POOLS):
    if index >= pools_count:
      break

    pool_data: address[4] = pools[index]

    pool: IPool = IPool(pool_data[1])
    tokens: address[2] = [staticcall pool.token0(), staticcall pool.token1()]

    for i: uint256 in range(2):
      if tokens[i] in seen:
        continue

      emerging: bool = False

      launcher: IPoolLauncher = self.v2_launcher
      # check if pool is CL pool
      if pool_data[3] != empty(address):
        launcher = self.cl_launcher

      # if pool is emerging and other token is pairable, set token as emerging
      if staticcall launcher.emerging(pool_data[1]) > 0 and staticcall launcher.isPairableToken(tokens[1 - i]):
        emerging = True

      seen.append(tokens[i])
      new_token: Token = self._token(tokens[i], _account, emerging)

      # Skip tokens that fail basic ERC20 calls
      if new_token.decimals != 0 and new_token.symbol != "":
        col.append(new_token)

  return col

@internal
@view
def _token(_address: address, _account: address, _emerging: bool) -> Token:
  bal: uint256 = empty(uint256)

  if _account != empty(address):
    bal = self._safe_balance_of(_address, _account)

  return Token(
    token_address=_address,
    symbol=self._safe_symbol(_address),
    decimals=self._safe_decimals(_address),
    account_balance=bal,
    listed=staticcall lp_shared.voter.isWhitelistedToken(_address),
    emerging=_emerging
  )

@external
@view
def safe_balance_of(_token: address, _address: address) -> uint256:
  """
  @notice Returns the balance if the call to balanceOf was successfull, otherwise 0
  @param _token The token to call
  @param _address The address to get the balanceOf
  """
  return self._safe_balance_of(_token, _address)

@internal
@view
def _safe_balance_of(_token: address, _address: address) -> uint256:
  response: Bytes[32] = raw_call(
      _token,
      abi_encode(_address, method_id=method_id("balanceOf(address)")),
      max_outsize=32,
      gas=100000,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[1]

  if len(response) > 0:
    return (abi_decode(response, uint256))

  return 0

@external
@view
def safe_decimals(_token: address) -> uint8:
  """
  @notice Returns the `ERC20.decimals()` result safely. Defaults to 18
  @param _token The token to call
  """
  return self._safe_decimals(_token)

@internal
@view
def _safe_decimals(_token: address) -> uint8:
  response: Bytes[32] = b""
  response = raw_call(
      _token,
      method_id("decimals()"),
      max_outsize=32,
      gas=50000,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[1]

  # Check response as revert_on_failure is set to False
  if len(response) > 0:
    return (abi_decode(response, uint8))

  return 0

@external
@view
def safe_symbol(_token: address) -> String[MAX_TOKEN_SYMBOL_LEN]:
  """
  @notice Returns the `ERC20.symbol()` safely (max 30 chars)
  @param _token The token to call
  """
  return self._safe_symbol(_token)

@internal
@view
def _safe_symbol(_token: address) -> String[MAX_TOKEN_SYMBOL_LEN]:
  """
  @notice Returns the `ERC20.symbol()` safely (max 30 chars)
  @param _token The token to call
  """
  response: Bytes[100] = raw_call(
      _token,
      method_id("symbol()"),
      # Min bytes to use abi_decode()
      max_outsize=100,
      gas=50000,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False
  )[1]

  resp_len: uint256 = len(response)

  if resp_len == 0:
    return ""

  # Check response as revert_on_failure is set to False
  # And that the symbol size is not some large value (probably spam)
  if resp_len > 0 and resp_len <= 96:
    return abi_decode(response, String[MAX_TOKEN_SYMBOL_LEN])

  return "-???-"
