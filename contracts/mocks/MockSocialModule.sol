// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ISocialModule.sol";

contract MockSocialModule is ISocialModule {
    mapping(address => TokenGateConfig) public tokenGates;
    bool public paused;

    function createTokenGate(
        address token,
        uint256 minHoldAmount,
        uint256 minHoldDuration,
        uint256 requiredLevel,
        bool requireVerification,
        bool enableTrading,
        bool enableStaking
    ) external override {
        tokenGates[token] = TokenGateConfig({
            minHoldAmount: minHoldAmount,
            minHoldDuration: minHoldDuration,
            requiredLevel: requiredLevel,
            requireVerification: requireVerification,
            enableTrading: enableTrading,
            enableStaking: enableStaking
        });
    }

    function recordTradeAction(
        address token,
        address trader,
        uint256 amount,
        bool isBuy
    ) external override {
        // No implementation needed for mock
    }

    function pause() external override {
        paused = true;
    }

    function unpause() external override {
        paused = false;
    }

    function initialize(address token, address registry) external {
        // No initialization needed for mock
    }
} 