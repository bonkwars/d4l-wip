// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface ILaunchpad {
    struct LaunchConfig {
        uint96 initialPrice;      // 12 bytes - Initial token price
        uint96 softCap;          // 12 bytes - Minimum raise target
        uint96 hardCap;          // 12 bytes - Maximum raise target
        uint32 startTime;        // 4 bytes  - Launch start time
        uint32 endTime;          // 4 bytes  - Launch end time
        uint16 pumpRewardBps;    // 2 bytes  - Pump reward in basis points
        uint8 status;           // 1 byte   - Launch status
        bool whitelistEnabled;  // 1 byte   - Whitelist status
    }

    struct PumpMetrics {
        uint96 totalVolume;      // 12 bytes - Total trading volume
        uint96 pumpScore;        // 12 bytes - Current pump score
        uint32 uniqueTraders;    // 4 bytes  - Number of unique traders
        uint32 lastPumpTime;     // 4 bytes  - Last pump action timestamp
        uint16 momentum;         // 2 bytes  - Current momentum (basis points)
        uint8 level;            // 1 byte   - Current pump level
        bool isPumping;         // 1 byte   - Whether token is pumping
    }

    struct SocialMetrics {
        uint32 holders;          // 4 bytes  - Total token holders
        uint32 interactions;     // 4 bytes  - Total social interactions
        uint16 viralityScore;    // 2 bytes  - Virality score (basis points)
        uint16 communityScore;   // 2 bytes  - Community engagement score
        uint8 tier;             // 1 byte   - Social tier level
        bool verified;          // 1 byte   - Verification status
    }

    event LaunchCreated(
        address indexed token,
        address indexed creator,
        uint96 initialPrice,
        uint96 hardCap,
        uint32 startTime,
        uint32 endTime
    );

    event PumpAction(
        address indexed token,
        address indexed user,
        uint96 amount,
        uint16 momentum,
        uint8 newLevel
    );

    event RewardDistributed(
        address indexed token,
        address indexed user,
        uint96 amount,
        string rewardType
    );

    event SocialInteraction(
        address indexed token,
        address indexed user,
        string actionType,
        uint16 score
    );

    /// @notice Creates a new token launch
    /// @param token Token address
    /// @param config Launch configuration
    /// @param metadataCid IPFS CID of token metadata
    function createLaunch(
        address token,
        LaunchConfig calldata config,
        string calldata metadataCid
    ) external payable;

    /// @notice Participates in a token launch
    /// @param token Token address
    /// @param amount Amount to contribute
    function participate(address token, uint96 amount) external payable;

    /// @notice Triggers a pump action for a token
    /// @param token Token address
    /// @param amount Amount to pump
    function pump(address token, uint96 amount) external payable;

    /// @notice Records a social interaction
    /// @param token Token address
    /// @param actionType Type of social action
    /// @param proof Proof of social action
    function recordSocialAction(address token, string calldata actionType, bytes calldata proof) external;

    /// @notice Claims pump rewards
    /// @param token Token address
    /// @return amount Amount of rewards claimed
    function claimPumpRewards(address token) external returns (uint96 amount);

    /// @notice Gets pump metrics for a token
    /// @param token Token address
    function getPumpMetrics(address token) external view returns (PumpMetrics memory);

    /// @notice Gets social metrics for a token
    /// @param token Token address
    function getSocialMetrics(address token) external view returns (SocialMetrics memory);

    /// @notice Gets launch status and info
    /// @param token Token address
    function getLaunchInfo(address token) external view returns (LaunchConfig memory);

    /// @notice Updates whitelist status for users
    /// @param token Token address
    /// @param users Array of user addresses
    /// @param status Whitelist status for users
    function updateWhitelist(address token, address[] calldata users, bool status) external;

    /// @notice Finalizes a token launch
    /// @param token Token address
    function finalizeLaunch(address token) external;

    /// @notice Gets user's pump rank and stats
    /// @param token Token address
    /// @param user User address
    /// @return rank User's rank
    /// @return score User's pump score
    /// @return rewards Pending rewards
    function getUserStats(address token, address user) external view returns (
        uint32 rank,
        uint96 score,
        uint96 rewards
    );
} 