# To test on OP Mainnet, pass these token addresses:
# * 0x4200000000000000000000000000000000000006 (weth)
# * 0x045D841ba37E180bC9b9D4da718E14b9ED7925d6 (garbaged unicode)

@external
@view
def safe_symbol(_token: address) -> String[10]:
  response: Bytes[100] = raw_call(
      _token,
      method_id("symbol()"),
      max_outsize=100,
      gas=50000,
      is_delegate_call=False,
      is_static_call=True,
      revert_on_failure=False,
  )[1]

  response_len: uint256 = len(response)

  # Min bytes to use abi_decode()
  if response_len > 0 and response_len <= 96:
    return abi_decode(response, String[10])

  return "-???-"
