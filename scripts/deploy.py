import os

from brownie import accounts, Sugar


def main():
    account = accounts.load('sugar')

    sugar = Sugar.deploy({'from': account})
    sugar.setup(
        os.getenv('VOTER_ADDRESS'),
        os.getenv('WRAPPED_BRIBE_FACTORY'),
        {'from': account}
    )
