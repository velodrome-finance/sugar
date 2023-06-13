# SPDX-License-Identifier: BUSL-1.1
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

    if 've' in contract_name:
        vesugar = VeSugar.deploy({'from': account})
        vesugar.setup(
            os.getenv('VOTER_ADDRESS'),
            os.getenv('WRAPPED_BRIBE_FACTORY'),
            os.getenv('REWARDS_DIST_ADDRESS'),
            {'from': account}
        )

    if 've' not in contract_name and 'pairs' not in contract_name:
        print('Set the `CONTRACT` environment variable to deploy a contract.')
