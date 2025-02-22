// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IHydraGovernance.sol";

contract MockHydraGovernance is IHydraGovernance {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function updateParameter(bytes32 parameter, uint256 newValue) external  {
        // Mock implementation
    }

    function getParameter(bytes32 parameter) external pure returns (uint256) {
        return 0; // Mock implementation
    }

    function hasRole(bytes32 role, address account) external view override returns (bool) {
        return account == owner; // Mock implementation - owner has all roles
    }
} 