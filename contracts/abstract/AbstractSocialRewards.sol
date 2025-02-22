// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "../interfaces/ISocialRewards.sol";
import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "solmate/src/utils/FixedPointMathLib.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../constants/constants.sol";

abstract contract AbstractSocialRewards is ISocialRewards, Owned {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    // Constants for rewards and streaks
    uint16 constant MAX_STREAK = 365;  // Maximum streak days
    uint16 constant STREAK_BONUS_BPS = 100; // 1% bonus per day
    uint16 constant MAX_BONUS_BPS = 10000; // 100% max bonus
    uint32 constant STREAK_RESET_PERIOD = 48 hours;

    // Packed storage for rewards data
    mapping(uint8 => RewardTier) private _tiers;
    mapping(uint256 => Achievement) private _achievements;
    mapping(address => UserStats) private _userStats;
    
    // Efficient mappings for user data
    mapping(address => mapping(uint256 => bool)) private _unlockedAchievements;
    mapping(address => mapping(uint8 => uint32)) private _lastClaim;
    mapping(address => uint32[]) private _userAchievements;
    
    // Achievement categories
    uint8 constant CATEGORY_TRADING = 1;
    uint8 constant CATEGORY_SOCIAL = 2;
    uint8 constant CATEGORY_COMMUNITY = 3;
    uint8 constant CATEGORY_SPECIAL = 4;

    constructor() Owned(msg.sender) {
        _initializeTiers();
    }

    /// @notice Records a social action
    function recordAction(
        address user,
        string calldata actionType,
        bytes calldata proof
    ) external override returns (uint16 points) {
        require(_verifySocialProof(actionType, proof), "Invalid proof");
        
        points = _calculateActionPoints(actionType);
        UserStats storage stats = _userStats[user];
        
        // Update user stats
        stats.totalPoints += points;
        stats.lastAction = uint32(block.timestamp);
        
        // Process streak
        (uint16 newStreak, uint16 bonus) = _processStreak(stats);
        if (bonus > 0) {
            points += bonus;
            stats.totalPoints += bonus;
        }
        
        // Check for achievements
        _checkAchievements(user, actionType, points);
        
        emit StreakUpdated(user, newStreak, bonus);
        return points;
    }

    /// @notice Claims achievement rewards
    function claimAchievement(
        uint256 achievementId
    ) external override returns (uint96 amount) {
        Achievement storage achievement = _achievements[achievementId];
        require(!achievement.claimed, "Already claimed");
        require(_unlockedAchievements[msg.sender][achievementId], "Not unlocked");
        
        achievement.claimed = true;
        amount = achievement.reward;
        
        // Apply tier multiplier
        UserStats storage stats = _userStats[msg.sender];
        uint96 multiplier = _tiers[stats.currentTier].multiplier;
        amount = uint96((uint256(amount) * multiplier) / 10000);
        
        stats.totalRewards += amount;
        _processRewardTransfer(msg.sender, amount);
        
        emit RewardClaimed(msg.sender, amount, stats.currentTier, "achievement");
        return amount;
    }

    /// @notice Claims tier rewards
    function claimTierRewards(
        uint8 tier
    ) external override returns (uint96 amount) {
        require(canClaimTierRewards(msg.sender, tier), "Cannot claim");
        
        RewardTier storage rewardTier = _tiers[tier];
        UserStats storage stats = _userStats[msg.sender];
        
        // Calculate rewards
        amount = _calculateTierRewards(stats.totalPoints, rewardTier);
        _lastClaim[msg.sender][tier] = uint32(block.timestamp);
        
        stats.totalRewards += amount;
        _processRewardTransfer(msg.sender, amount);
        
        emit RewardClaimed(msg.sender, amount, tier, "tier");
        return amount;
    }

    /// @notice Updates user streak
    function updateStreak(
        address user
    ) external override returns (uint16 newStreak, uint16 bonus) {
        UserStats storage stats = _userStats[user];
        return _processStreak(stats);
    }

    // View functions
    function getUserAchievements(
        address user
    ) external view override returns (Achievement[] memory) {
        uint32[] storage achievementIds = _userAchievements[user];
        Achievement[] memory achievements = new Achievement[](achievementIds.length);
        
        for (uint256 i = 0; i < achievementIds.length; i++) {
            achievements[i] = _achievements[achievementIds[i]];
        }
        
        return achievements;
    }

    function getUserStats(
        address user
    ) external view override returns (UserStats memory) {
        return _userStats[user];
    }

    function getTierInfo(
        uint8 tier
    ) external view override returns (RewardTier memory) {
        return _tiers[tier];
    }

    function canClaimTierRewards(
        address user,
        uint8 tier
    ) public view override returns (bool) {
        RewardTier storage rewardTier = _tiers[tier];
        UserStats storage stats = _userStats[user];
        
        return stats.totalPoints >= rewardTier.threshold &&
            block.timestamp >= _lastClaim[user][tier] + rewardTier.cooldown;
    }

    function getUserMultiplier(
        address user
    ) external view override returns (uint96) {
        UserStats storage stats = _userStats[user];
        return _tiers[stats.currentTier].multiplier;
    }

    function getLeaderboardPosition(
        address user
    ) external view override returns (uint32 rank, uint96 score, uint32 total) {
        // Implementation specific
        return (0, 0, 0);
    }

    function getTopPerformers(
        uint8 count
    ) external view override returns (address[] memory users, uint96[] memory scores) {
        // Implementation specific
        return (new address[](0), new uint96[](0));
    }

    // Internal functions
    function _initializeTiers() internal virtual {
        // Implementation specific
    }

    function _calculateActionPoints(
        string calldata actionType
    ) internal pure virtual returns (uint16) {
        // Implementation specific
        return 0;
    }

    function _processStreak(
        UserStats storage stats
    ) internal returns (uint16 newStreak, uint16 bonus) {
        uint32 timeSinceLastAction = uint32(block.timestamp) - stats.lastAction;
        
        if (timeSinceLastAction <= STREAK_RESET_PERIOD) {
            newStreak = stats.streak < MAX_STREAK ? stats.streak + 1 : MAX_STREAK;
            bonus = uint16(newStreak * STREAK_BONUS_BPS < MAX_BONUS_BPS ? newStreak * STREAK_BONUS_BPS : MAX_BONUS_BPS);
        } else {
            newStreak = 1;
            bonus = 0;
        }
        
        stats.streak = newStreak;
        return (newStreak, bonus);
    }

    function _checkAchievements(
        address user,
        string calldata actionType,
        uint16 points
    ) internal virtual {
        // Implementation specific
    }

    function _calculateTierRewards(
        uint96 points,
        RewardTier storage tier
    ) internal view virtual returns (uint96) {
        return uint96((uint256(points) * tier.bonusBps) / 10000);
    }

    function _processRewardTransfer(
        address user,
        uint96 amount
    ) internal virtual {
        // Implementation specific
    }

    function _verifySocialProof(
        string calldata actionType,
        bytes calldata proof
    ) internal view virtual returns (bool) {
        // Implementation specific
        return false;
    }
} 