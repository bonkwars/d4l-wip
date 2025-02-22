// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPriceOracle {
    // Events
    event PriceFeedUpdated(address indexed token, address indexed feed);
    event PriceUpdated(address indexed token, uint256 price);
    event PriceDeviation(address indexed token, uint256 oldPrice, uint256 newPrice);

    // External functions
    function getPrice(address token) external view returns (uint256);
    function updatePrice(address token) external returns (uint256);
    function setPriceFeed(address token, address feed) external;
    function pause() external;
    function unpause() external;

    // View functions
    function priceFeeds(address token) external view returns (address);
    function lastPriceUpdate(address token) external view returns (uint256);
    function prices(address token) external view returns (uint256);
} 