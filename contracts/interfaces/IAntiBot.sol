// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface IAntiBot {
    event BotDetected(address indexed bot, string reason);
    event ProtectionConfigUpdated(
        uint256 maxTransactionAmount,
        uint256 timeWindow,
        uint256 maxTransactionsPerWindow
    );

    /// @notice Checks if an address is potentially a bot
    /// @param account The address to check
    /// @param amount The transaction amount
    /// @return True if the address is suspected to be a bot
    function isBot(address account, uint256 amount) external view returns (bool);

    /// @notice Updates the protection configuration
    /// @param maxAmount Maximum transaction amount
    /// @param window Time window for transaction counting
    /// @param maxTxPerWindow Maximum transactions per window
    function updateProtectionConfig(
        uint256 maxAmount,
        uint256 window,
        uint256 maxTxPerWindow
    ) external;

    /// @notice Records a transaction for bot detection
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Transaction amount
    function recordTransaction(address from, address to, uint256 amount) external;

    /// @notice Gets the current protection configuration
    function getProtectionConfig() external view returns (
        uint256 maxAmount,
        uint256 window,
        uint256 maxTxPerWindow
    );

    /// @notice Gets transaction statistics for an address
    /// @param account The address to check
    function getTransactionStats(address account) external view returns (
        uint256 totalTransactions,
        uint256 transactionsInWindow,
        uint256 lastTransactionTime
    );

    function whitelistAddress(address token, bool status) external;

    function validateTrade(
        address trader,
        uint256 amount,
        bool isBuy
    ) external view returns (bool);

    function initialize(address token, address registry) external;
}