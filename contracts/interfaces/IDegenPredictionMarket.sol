// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDegenPredictionMarket {
    enum MarketStatus {
        Open,
        Closed,
        Resolved,
        Cancelled
    }

    enum MarketOutcome {
        Undecided,
        Yes,
        No
    }

    struct Market {
        uint256 id;
        string question;
        uint256 createdAt;
        uint256 expiresAt;
        uint256 resolutionWindow;
        address creator;
        uint256 totalYesAmount;
        uint256 totalNoAmount;
        MarketStatus status;
        MarketOutcome outcome;
        uint256 minBetAmount;
        uint256 maxBetAmount;
        uint256 creatorStake;
        uint256 protocolFee;
    }

    struct Position {
        uint256 marketId;
        address user;
        bool isYes;
        uint256 amount;
        bool claimed;
    }

    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        uint256 expiresAt,
        uint256 resolutionWindow,
        uint256 minBetAmount,
        uint256 maxBetAmount,
        uint256 creatorStake
    );

    event PositionTaken(
        uint256 indexed marketId,
        address indexed user,
        bool isYes,
        uint256 amount
    );

    event MarketResolved(
        uint256 indexed marketId,
        MarketOutcome outcome,
        address resolver
    );

    event RewardsClaimed(
        uint256 indexed marketId,
        address indexed user,
        uint256 amount
    );

    event MarketCancelled(
        uint256 indexed marketId,
        string reason
    );

    function createMarket(
        string calldata question,
        uint256 expiresAt,
        uint256 resolutionWindow,
        uint256 minBetAmount,
        uint256 maxBetAmount,
        uint256 creatorStake
    ) external returns (uint256 marketId);

    function takePosition(
        uint256 marketId,
        bool isYes,
        uint256 amount
    ) external;

    function resolveMarket(
        uint256 marketId,
        MarketOutcome outcome
    ) external;

    function claimRewards(uint256 marketId) external returns (uint256 rewards);

    function cancelMarket(
        uint256 marketId,
        string calldata reason
    ) external;

    function getMarket(uint256 marketId) external view returns (Market memory);

    function getPosition(uint256 marketId, address user) 
        external 
        view 
        returns (Position memory);

    function calculatePotentialReward(
        uint256 marketId,
        bool isYes,
        uint256 amount
    ) external view returns (uint256 potentialReward);

    function getMarketsByStatus(MarketStatus status)
        external
        view
        returns (uint256[] memory marketIds);
} 