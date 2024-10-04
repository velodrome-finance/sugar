# SPDX-License-Identifier: BUSL-1.1
import os

from brownie import accounts, VeSugar, LpSugar, RelaySugar


def main():
    contract_name = str(os.getenv('CONTRACT')).lower()
    chain_name = str(os.getenv('CHAIN')).upper()

    if os.getenv('PROD'):
        account = accounts.load('sugar')
    else:
        account = accounts[0]

    if 'lp' in contract_name:
        LpSugar.deploy(
            os.getenv(chain_name + '_REGISTRY'),
            os.getenv(chain_name + '_VOTER'),
            str(os.getenv(chain_name + '_FACTORIES')).split(','),
            os.getenv(chain_name + '_CONVERTOR'),
            os.getenv(chain_name + '_SLIPSTREAM_HELPER'),
            os.getenv(chain_name + '_ALM_FACTORY'),
            {'from': account}
        )

    if 've' in contract_name:
        VeSugar.deploy(
            os.getenv('VOTER_ADDRESS'),
            os.getenv('DIST_ADDRESS'),
            os.getenv('GOVERNOR_ADDRESS'),
            {'from': account}
        )

    if 'relay' in contract_name:
        RelaySugar.deploy(
            str(os.getenv('RELAY_REGISTRY_ADDRESSES')).split(','),
            os.getenv('VOTER_ADDRESS'),
            {'from': account}
        )

    if 've' not in contract_name and 'lp' not in contract_name:
        print('Set the `CONTRACT` environment variable to deploy a contract.')
