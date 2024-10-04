// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/Script.sol";
import "contracts/helpers/FactoryRegistry.sol";

contract DeployFactoryRegistry is Script {

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.addr(deployPrivateKey);

    function run() public {

        vm.startBroadcast(deployerAddress);

        FactoryRegistry factoryRegistry = new FactoryRegistry();

        vm.stopBroadcast();
        console.log("FactoryRegistry deployed at: ", address(factoryRegistry));

    }
}
