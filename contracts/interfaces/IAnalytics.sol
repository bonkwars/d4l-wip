// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface IAnalytics {
    struct TokenMetrics {
        uint256 price;           // Current token price
        uint256 volume24h;       // 24h trading volume
        uint256 liquidity;       // Total liquidity
        uint32 holders;          // Number of token holders
        uint32 transactions24h;  // 24h transaction count
        uint32 buys24h;         // 24h buy transactions
        uint32 sells24h;        // 24h sell transactions
    }

    struct PoolMetrics {
        uint256 tvl;            // Total value locked
        uint256 volume24h;      // 24h trading volume
        uint256 fees24h;        // 24h fees collected
        uint32 swapCount24h;    // 24h swap count
        uint32 uniqueTraders24h;// 24h unique traders
        uint16 priceImpact;     // Current price impact (basis points)
        uint16 slippage;        // Average slippage (basis points)
    }

    struct UserMetrics {
        uint256 totalValue;     // Total value of holdings
        uint256 totalVolume;    // Total trading volume
        uint32 tokenCount;      // Number of tokens held
        uint32 poolCount;       // Number of pools participated in
        uint32 transactions;    // Total transactions
        uint32 lastActivity;    // Last activity timestamp
    }

    event MetricsUpdated(
        address indexed token,
        uint256 price,
        uint256 volume24h,
        uint256 liquidity
    );

    /// @notice Updates metrics for a token
    /// @param token The token address
    /// @param metrics The new metrics
    function updateTokenMetrics(address token, TokenMetrics calldata metrics) external;

    /// @notice Updates metrics for a pool
    /// @param pool The pool address
    /// @param metrics The new metrics
    function updatePoolMetrics(address pool, PoolMetrics calldata metrics) external;

    /// @notice Updates metrics for a user
    /// @param user The user address
    /// @param metrics The new metrics
    function updateUserMetrics(address user, UserMetrics calldata metrics) external;

    /// @notice Gets metrics for a token
    /// @param token The token address
    function getTokenMetrics(address token) external view returns (TokenMetrics memory);

    /// @notice Gets metrics for a pool
    /// @param pool The pool address
    function getPoolMetrics(address pool) external view returns (PoolMetrics memory);

    /// @notice Gets metrics for a user
    /// @param user The user address
    function getUserMetrics(address user) external view returns (UserMetrics memory);

    /// @notice Gets top tokens by volume
    /// @param count Number of tokens to return
    function getTopTokensByVolume(uint256 count) external view returns (address[] memory);

    /// @notice Gets top pools by TVL
    /// @param count Number of pools to return
    function getTopPoolsByTVL(uint256 count) external view returns (address[] memory);

    /// @notice Gets top traders by volume
    /// @param count Number of traders to return
    function getTopTradersByVolume(uint256 count) external view returns (address[] memory);

    /// @notice Gets historical price data for a token
    /// @param token The token address
    /// @param startTime Start timestamp
    /// @param endTime End timestamp
    /// @param interval Time interval in seconds
    function getPriceHistory(
        address token,
        uint256 startTime,
        uint256 endTime,
        uint256 interval
    ) external view returns (uint256[] memory timestamps, uint256[] memory prices);

    /// @notice Gets historical volume data for a token
    /// @param token The token address
    /// @param startTime Start timestamp
    /// @param endTime End timestamp
    /// @param interval Time interval in seconds
    function getVolumeHistory(
        address token,
        uint256 startTime,
        uint256 endTime,
        uint256 interval
    ) external view returns (uint256[] memory timestamps, uint256[] memory volumes);
} 