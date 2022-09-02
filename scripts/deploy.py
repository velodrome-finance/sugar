import os

from brownie import accounts, VeSugar, PairsSugar


def main():
    account = accounts.load('sugar')

    psugar = PairsSugar.deploy({'from': account})
    psugar.setup(
        os.getenv('VOTER_ADDRESS'),
        os.getenv('WRAPPED_BRIBE_FACTORY'),
        {'from': account}
    )

    vesugar = VeSugar.deploy({'from': account})
    vesugar.setup(
        os.getenv('VOTER_ADDRESS'),
        os.getenv('REWARDS_DIST_ADDRESS'),
        {'from': account}
    )
