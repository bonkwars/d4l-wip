// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISocialModule {
    struct TokenGateConfig {
        uint256 minHoldAmount;
        uint256 minHoldDuration;
        uint256 requiredLevel;
        bool requireVerification;
        bool enableTrading;
        bool enableStaking;
    }

    function recordTradeAction(
        address token,
        address trader,
        uint256 amount,
        bool isBuy
    ) external;

    function createTokenGate(
        address token,
        uint256 minHoldAmount,
        uint256 minHoldDuration,
        uint256 requiredLevel,
        bool requireVerification,
        bool enableTrading,
        bool enableStaking
    ) external;

    function pause() external;
    function unpause() external;
} 