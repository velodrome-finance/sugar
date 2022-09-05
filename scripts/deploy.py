import os

from brownie import accounts, VeSugar, PairsSugar


def main():
    contract_name = str(os.getenv('CONTRACT')).lower()
    account = accounts.load('sugar')

    if 'pairs' in contract_name:
        psugar = PairsSugar.deploy({'from': account})
        psugar.setup(
            os.getenv('VOTER_ADDRESS'),
            os.getenv('WRAPPED_BRIBE_FACTORY'),
            {'from': account}
        )
    elif 've' in contract_name:
        vesugar = VeSugar.deploy({'from': account})
        vesugar.setup(
            os.getenv('VOTER_ADDRESS'),
            os.getenv('REWARDS_DIST_ADDRESS'),
            os.getenv('PAIRS_SUGAR_ADDRESS'),
            {'from': account}
        )
    else:
        print('Set the `CONTRACT` environment variable to deploy a contract.')
