// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface ISocialRewards {
    struct RewardTier {
        uint96 threshold;       // 12 bytes - Points threshold for tier
        uint96 multiplier;      // 12 bytes - Reward multiplier in basis points
        uint32 cooldown;        // 4 bytes  - Claim cooldown period
        uint16 bonusBps;        // 2 bytes  - Additional bonus in basis points
        uint8 level;           // 1 byte   - Tier level
        bool unlocked;         // 1 byte   - Whether tier is unlocked
    }

    struct Achievement {
        string name;           // Achievement name
        string description;    // Achievement description
        uint96 reward;         // 12 bytes - Reward amount
        uint32 unlockedTime;   // 4 bytes  - When achievement was unlocked
        uint16 points;         // 2 bytes  - Points awarded
        uint8 category;        // 1 byte   - Achievement category
        bool claimed;          // 1 byte   - Whether reward was claimed
    }

    struct UserStats {
        uint96 totalPoints;     // 12 bytes - Total points earned
        uint96 totalRewards;    // 12 bytes - Total rewards earned
        uint32 achievements;    // 4 bytes  - Number of achievements
        uint32 lastAction;      // 4 bytes  - Last action timestamp
        uint16 streak;          // 2 bytes  - Current action streak
        uint8 currentTier;     // 1 byte   - Current reward tier
        bool active;           // 1 byte   - Whether user is active
    }

    event AchievementUnlocked(
        address indexed user,
        string name,
        uint16 points,
        uint96 reward
    );

    event RewardClaimed(
        address indexed user,
        uint96 amount,
        uint8 tier,
        string source
    );

    event TierUpgraded(
        address indexed user,
        uint8 oldTier,
        uint8 newTier,
        uint96 totalPoints
    );

    event StreakUpdated(
        address indexed user,
        uint16 newStreak,
        uint16 bonusPoints
    );

    /// @notice Records a social action and awards points
    /// @param user User address
    /// @param actionType Type of social action
    /// @param proof Proof of action
    /// @return points Points awarded
    function recordAction(
        address user,
        string calldata actionType,
        bytes calldata proof
    ) external returns (uint16 points);

    /// @notice Claims rewards for a specific achievement
    /// @param achievementId Achievement identifier
    /// @return amount Amount of rewards claimed
    function claimAchievement(uint256 achievementId) external returns (uint96 amount);

    /// @notice Claims tier rewards
    /// @param tier Tier level
    /// @return amount Amount of rewards claimed
    function claimTierRewards(uint8 tier) external returns (uint96 amount);

    /// @notice Updates user's streak
    /// @param user User address
    /// @return newStreak New streak count
    /// @return bonus Bonus points awarded
    function updateStreak(address user) external returns (
        uint16 newStreak,
        uint16 bonus
    );

    /// @notice Gets user's achievements
    /// @param user User address
    /// @return achievements Array of user achievements
    function getUserAchievements(address user) external view returns (Achievement[] memory);

    /// @notice Gets user's stats
    /// @param user User address
    function getUserStats(address user) external view returns (UserStats memory);

    /// @notice Gets reward tier info
    /// @param tier Tier level
    function getTierInfo(uint8 tier) external view returns (RewardTier memory);

    /// @notice Checks if user can claim tier rewards
    /// @param user User address
    /// @param tier Tier level
    function canClaimTierRewards(address user, uint8 tier) external view returns (bool);

    /// @notice Gets user's current multiplier
    /// @param user User address
    /// @return multiplier Current reward multiplier
    function getUserMultiplier(address user) external view returns (uint96);

    /// @notice Gets leaderboard position
    /// @param user User address
    /// @return rank User's rank
    /// @return score User's score
    /// @return total Total participants
    function getLeaderboardPosition(address user) external view returns (
        uint32 rank,
        uint96 score,
        uint32 total
    );

    /// @notice Gets top performers
    /// @param count Number of entries to return
    /// @return users Array of top user addresses
    /// @return scores Array of user scores
    function getTopPerformers(uint8 count) external view returns (
        address[] memory users,
        uint96[] memory scores
    );
} 