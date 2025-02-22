// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface IStaking {
    struct StakeInfo {
        uint96 amount;         // 12 bytes - Amount staked
        uint32 startTime;      // 4 bytes  - Start time of stake
        uint32 lockTime;       // 4 bytes  - Lock duration
        uint32 lastClaim;      // 4 bytes  - Last reward claim
        uint16 multiplier;     // 2 bytes  - Reward multiplier (basis points)
        uint8 tier;           // 1 byte   - Staking tier
        bool locked;          // 1 byte   - Whether stake is locked
    }

    struct RewardConfig {
        uint32 periodDuration;  // 4 bytes  - Duration of reward period
        uint32 cooldown;        // 4 bytes  - Cooldown between claims
        uint16 baseRate;        // 2 bytes  - Base reward rate (basis points)
        uint16 bonusRate;       // 2 bytes  - Bonus rate (basis points)
        uint8 maxTier;         // 1 byte   - Maximum staking tier
        uint8 minLockTime;     // 1 byte   - Minimum lock time (in days)
        bool active;           // 1 byte   - Whether rewards are active
        uint8 reserved;        // 1 byte   - Reserved for future use
    }

    event Staked(
        address indexed user,
        uint96 amount,
        uint32 lockTime,
        uint8 tier
    );

    event Unstaked(
        address indexed user,
        uint96 amount,
        uint96 penalty
    );

    event RewardClaimed(
        address indexed user,
        uint96 amount,
        uint16 multiplier
    );

    event TierUpgraded(
        address indexed user,
        uint8 oldTier,
        uint8 newTier
    );

    /// @notice Stakes tokens
    /// @param amount Amount to stake
    /// @param lockTime Lock duration (0 for flexible)
    function stake(uint96 amount, uint32 lockTime) external;

    /// @notice Unstakes tokens
    /// @param amount Amount to unstake
    /// @return penalty Early unstaking penalty if any
    function unstake(uint96 amount) external returns (uint96 penalty);

    /// @notice Claims pending rewards
    /// @return amount Amount of rewards claimed
    function claimRewards() external returns (uint96 amount);

    /// @notice Gets pending rewards for a user
    /// @param user User address
    function getPendingRewards(address user) external view returns (uint96);

    /// @notice Gets stake information for a user
    /// @param user User address
    function getStakeInfo(address user) external view returns (StakeInfo memory);

    /// @notice Gets the current reward configuration
    function getRewardConfig() external view returns (RewardConfig memory);

    /// @notice Updates a user's staking tier
    /// @param user User address
    /// @param newTier New tier level
    function updateTier(address user, uint8 newTier) external;

    /// @notice Calculates rewards for a period
    /// @param amount Staked amount
    /// @param duration Duration in seconds
    /// @param tier Staking tier
    /// @param multiplier Reward multiplier
    function calculateRewards(
        uint96 amount,
        uint32 duration,
        uint8 tier,
        uint16 multiplier
    ) external view returns (uint96);

    /// @notice Gets the early unstaking penalty
    /// @param amount Amount to unstake
    /// @param remainingLockTime Remaining lock time
    function getUnstakePenalty(uint96 amount, uint32 remainingLockTime) external view returns (uint96);

    /// @notice Gets total staked amount
    function totalStaked() external view returns (uint96);

    /// @notice Gets total rewards distributed
    function totalRewardsDistributed() external view returns (uint96);

    /// @notice Gets APR for a tier
    /// @param tier Staking tier
    function getAPR(uint8 tier) external view returns (uint16);
} 