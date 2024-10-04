// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "openzeppelin/openzeppelin-contracts@5.0.2/contracts/access/Ownable.sol";
import {EnumerableSet} from "openzeppelin/openzeppelin-contracts@5.0.2/contracts/utils/structs/EnumerableSet.sol";

/// @title Sugar Factory Registry
/// @author @velodrome.finance
/// @notice Sugar Factory Registry to keep track of leaf pool factories
contract FactoryRegistry is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Array of poolFactories
    EnumerableSet.AddressSet private _poolFactories;

    constructor() Ownable(msg.sender) {}

    function approve(address poolFactory) external onlyOwner {
        require(!_poolFactories.contains(poolFactory), "AE");
        _poolFactories.add(poolFactory);
    }

    function unapprove(address poolFactory) external onlyOwner {
        require(_poolFactories.contains(poolFactory), "NE");
        _poolFactories.remove(poolFactory);
    }

    function factoriesToPoolFactory(address poolFactory) external pure returns (address, address) {
        return (address(0), poolFactory);
    }

    function poolFactories() external view returns (address[] memory) {
        return _poolFactories.values();
    }
}
