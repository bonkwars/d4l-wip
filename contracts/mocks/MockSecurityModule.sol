// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ISecurityModule.sol";

contract MockSecurityModule is ISecurityModule {
    mapping(bytes32 => SecurityConfig) public securityConfigs;
    bool public paused;

    function updateSecurityConfig(
        bytes32 tokenType,
        SecurityConfig calldata config
    ) external override {
        securityConfigs[tokenType] = config;
    }

    function validateTrading(
        address token,
        address trader,
        uint256 amount,
        bool isBuy
    ) external view override returns (bool) {
        return true; // Always allow trading in mock
    }

    function pause() external override {
        paused = true;
    }

    function unpause() external override {
        paused = false;
    }

    function initialize(address token, address registry) external override {
        // No initialization needed for mock
    }
} 