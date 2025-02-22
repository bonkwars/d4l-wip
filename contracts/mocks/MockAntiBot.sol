// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IAntiBot.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MockAntiBot is IAntiBot, Initializable {
    address public token;
    address public registry;
    mapping(address => bool) public whitelisted;
    uint256 public maxTransactionAmount;
    uint256 public timeWindow;
    uint256 public maxTransactionsPerWindow;

    function initialize(address _token, address _registry) external initializer {
        token = _token;
        registry = _registry;
    }

    function whitelistAddress(address _token, bool status) external override {
        require(_token == token, "Invalid token");
        whitelisted[_token] = status;
    }

    function updateProtectionConfig(
        uint256 _maxTransactionAmount,
        uint256 _timeWindow,
        uint256 _maxTransactionsPerWindow
    ) external override {
        maxTransactionAmount = _maxTransactionAmount;
        timeWindow = _timeWindow;
        maxTransactionsPerWindow = _maxTransactionsPerWindow;
    }

    function validateTrade(
        address trader,
        uint256 amount,
        bool isBuy
    ) external view override returns (bool) {
        return true; // Mock implementation always returns true
    }

    function isBot(address account, uint256 amount) external view override returns (bool) {
        return false; // Mock implementation always returns false
    }

    function getProtectionConfig() external view override returns (
        uint256 _maxTransactionAmount,
        uint256 _timeWindow,
        uint256 _maxTransactionsPerWindow
    ) {
        return (maxTransactionAmount, timeWindow, maxTransactionsPerWindow);
    }

    function getTransactionStats(address account) external view override returns (
        uint256 totalTransactions,
        uint256 transactionsInWindow,
        uint256 lastTransactionTime
    ) {
        return (0, 0, 0); // Mock implementation returns empty stats
    }

    function recordTransaction(address from, address to, uint256 amount) external override {
        // Mock implementation does nothing
    }
} 