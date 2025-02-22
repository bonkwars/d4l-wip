// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDegen4LifeEvents {
    event TokenCreated(address indexed token, address indexed creator);
    event PoolInitialized(address indexed pool, address indexed token);
    event TradeExecuted(
        address indexed trader,
        address indexed token,
        uint256 amount,
        bool isBuy
    );
    // Standardize all major events
} 