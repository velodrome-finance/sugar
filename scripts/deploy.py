import os

from brownie import accounts, VeSugar, LpSugar


def main():
    contract_name = str(os.getenv('CONTRACT')).lower()
    account = accounts.load('sugar')

    if 'lp' in contract_name:
        lpsugar = LpSugar.deploy({'from': account})
        lpsugar.setup(
            os.getenv('VOTER_ADDRESS'),
            os.getenv('REGISTRY_ADDRESS'),
            os.getenv('V1_FACTORY_ADDRESS'),
            {'from': account}
        )

    if 've' in contract_name:
        vesugar = VeSugar.deploy({'from': account})
        vesugar.setup(
            os.getenv('VOTER_ADDRESS'),
            os.getenv('DIST_ADDRESS'),
            {'from': account}
        )

    if 've' not in contract_name and 'lp' not in contract_name:
        print('Set the `CONTRACT` environment variable to deploy a contract.')
