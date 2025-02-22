// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISecurityModule {
    struct SecurityConfig {
        uint256 maxTransactionAmount;
        uint256 timeWindow;
        uint256 maxTransactionsPerWindow;
        uint256 lockDuration;
        uint256 minLiquidityPercentage;
        uint256 maxSellPercentage;
    }

    function updateSecurityConfig(
        bytes32 tokenType,
        SecurityConfig calldata config
    ) external;

    function validateTrading(
        address token,
        address trader,
        uint256 amount,
        bool isBuy
    ) external view returns (bool);

    function pause() external;
    function unpause() external;

    function initialize(address token, address registry) external;
} 