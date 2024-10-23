# SPDX-License-Identifier: BUSL-1.1
import os

from brownie import accounts, VeSugar, LpSugar, LpSugarModule, RelaySugar, FactoryRegistry


def main():
    contract_name = str(os.getenv('CONTRACT')).lower()
    chain_id = os.getenv('CHAIN_ID')

    if os.getenv('PROD'):
        account = accounts.load('sugar')
    else:
        account = accounts[0]

    if 'lp' in contract_name:
        lp_module: LpSugarModule = LpSugarModule.deploy(
            os.getenv(f'VOTER_{chain_id}'),
            os.getenv(f'REGISTRY_{chain_id}'),
            os.getenv(f'CONVERTOR_{chain_id}'),
            os.getenv(f'SLIPSTREAM_HELPER_{chain_id}'),
            os.getenv(f'ALM_FACTORY_{chain_id}'),
            {'from': account}
        )
        LpSugar.deploy(
            os.getenv(f'VOTER_{chain_id}'),
            os.getenv(f'REGISTRY_{chain_id}'),
            os.getenv(f'CONVERTOR_{chain_id}'),
            os.getenv(f'SLIPSTREAM_HELPER_{chain_id}'),
            os.getenv(f'ALM_FACTORY_{chain_id}'),
            lp_module.address,
            {'from': account}
        )

    if 've' in contract_name:
        VeSugar.deploy(
            os.getenv(f'VOTER_{chain_id}'),
            os.getenv(f'DIST_{chain_id}'),
            os.getenv(f'GOVERNOR_{chain_id}'),
            {'from': account}
        )

    if 'relay' in contract_name:
        RelaySugar.deploy(
            str(os.getenv(f'RELAY_REGISTRY_ADDRESSES_{chain_id}')).split(','),
            os.getenv(f'VOTER_{chain_id}'),
            {'from': account}
        )

    if 'registry' in contract_name:
        FactoryRegistry.deploy(
            str(os.getenv(f'FACTORIES_{chain_id}')).split(','),
            {'from': account}
        )

    if 've' not in contract_name and 'lp' not in contract_name:
        print('Set the `CONTRACT` environment variable to deploy a contract.')
