// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPredictionMarket {
    struct Market {
        address token;
        uint256 startTime;
        uint256 endTime;
        uint256 resolutionTime;
        uint256 totalYesAmount;
        uint256 totalNoAmount;
        bool resolved;
        bool outcome;
        string description;
    }

    struct Position {
        uint256 yesAmount;
        uint256 noAmount;
        bool claimed;
    }

    event MarketCreated(bytes32 indexed marketId, address indexed token, string description);
    event PositionTaken(bytes32 indexed marketId, address indexed user, bool isYes, uint256 amount);
    event MarketResolved(bytes32 indexed marketId, bool outcome);
    event RewardsClaimed(bytes32 indexed marketId, address indexed user, uint256 amount);

    function createMarket(
        address token,
        uint256 duration,
        string calldata description
    ) external returns (bytes32);

    function takePosition(
        bytes32 marketId,
        bool isYes,
        uint256 amount
    ) external;

    function resolveMarket(
        bytes32 marketId,
        bool outcome
    ) external;

    function claimRewards(bytes32 marketId) external;

    function getMarket(bytes32 marketId) external view returns (Market memory);

    function getPosition(
        bytes32 marketId,
        address user
    ) external view returns (Position memory);
} 