// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface IChainlinkOracle {
    /// @notice Gets the latest price for a token in USD with 8 decimals
    /// @param token The token address to get the price for
    /// @return price The latest price with 8 decimals
    /// @return updatedAt The timestamp of the latest update
    function getLatestPrice(address token) external view returns (uint256 price, uint256 updatedAt);

    /// @notice Gets the price feed address for a token
    /// @param token The token address
    /// @return The Chainlink price feed address
    function getPriceFeed(address token) external view returns (address);

    /// @notice Sets or updates the price feed for a token
    /// @param token The token address
    /// @param priceFeed The Chainlink price feed address
    function setPriceFeed(address token, address priceFeed) external;

    /// @notice Checks if a price feed exists for a token
    /// @param token The token address
    /// @return Whether the price feed exists
    function hasPriceFeed(address token) external view returns (bool);

    /// @notice Event emitted when a price feed is set or updated
    event PriceFeedSet(address indexed token, address indexed priceFeed);
} 