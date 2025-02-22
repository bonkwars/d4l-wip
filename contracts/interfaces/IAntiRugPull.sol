// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface IAntiRugPull {
    struct LockConfig {
        uint256 lockDuration;
        uint256 minLiquidityPercentage;
        uint256 maxSellPercentage;
        bool ownershipRenounced;
    }

    event LiquidityLocked(uint256 amount, uint256 unlockTime);
    event OwnershipRenounced(address indexed previousOwner);
    event LockConfigUpdated(LockConfig config);
    event MaxSellLimitUpdated(uint256 maxSellPercentage);

    /// @notice Locks liquidity for a specified duration
    /// @param amount Amount of liquidity to lock
    /// @param duration Lock duration in seconds
    function lockLiquidity(uint256 amount, uint256 duration) external;

    /// @notice Renounces ownership of the contract
    function renounceOwnership() external;

    /// @notice Updates the lock configuration
    /// @param config New lock configuration
    function updateLockConfig(LockConfig calldata config) external;

    /// @notice Checks if a sell transaction would violate anti-rug rules
    /// @param seller Address attempting to sell
    /// @param amount Amount being sold
    /// @return allowed Whether the sell is allowed
    /// @return reason Reason if not allowed
    function canSell(address seller, uint256 amount) external view returns (bool allowed, string memory reason);

    /// @notice Gets the current lock configuration
    function getLockConfig() external view returns (LockConfig memory);

    /// @notice Gets the amount of locked liquidity
    function getLockedLiquidity() external view returns (uint256 amount, uint256 unlockTime);

    /// @notice Checks if the contract has renounced ownership
    function isOwnershipRenounced() external view returns (bool);

    /// @notice Gets the maximum allowed sell amount
    function getMaxSellAmount() external view returns (uint256);

    function setWhitelisted(
        address token,
        address account,
        bool status
    ) external;

    function checkSellLimit(address token, uint256 amount) external returns (bool);

    function initialize(address token, address registry) external;
} 