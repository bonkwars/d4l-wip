// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceFeed {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

/**
 * @title MockChainlinkAggregator
 * @notice Simplified mock that just returns fixed values
 */
contract MockChainlinkAggregator is IPriceFeed {
    uint8 public constant DECIMALS = 8;
    int256 private price;
    uint80 private roundId;
    uint256 private timestamp;

    constructor() {
        price = 100000000; // $1.00 with 8 decimals
        roundId = 1;
        timestamp = block.timestamp;
    }

    function latestRoundData() external view override returns (
        uint80 roundId_,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (roundId, price, timestamp, timestamp, roundId);
    }

    function setPrice(uint256 _price) external {
        require(_price > 0, "Price must be positive");
        price = int256(_price);
        roundId++;
        timestamp = block.timestamp;
    }
} 