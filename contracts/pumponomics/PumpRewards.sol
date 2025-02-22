// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ITokenomics.sol";


contract PumpRewards {
    struct PumpStats {
        uint256 totalPumped;
        uint256 lastPumpTime;
        uint256 pumpStreak;
        uint256 rewardMultiplier;
    }

    struct RewardTier {
        uint256 minPump;
        uint256 multiplier;
        uint256 duration;
    }

    // State variables
    mapping(address => mapping(address => PumpStats)) public pumpStats; // token => user => stats
    mapping(uint256 => RewardTier) public rewardTiers;
    uint256 public constant MAX_MULTIPLIER = 500; // 5x
    uint256 public constant STREAK_BONUS = 10; // 10% per streak
    uint256 public constant MAX_STREAK = 10;
    uint256 public constant STREAK_RESET_TIME = 24 hours;

    IERC20 public immutable rewardToken;
    ITokenomics public immutable tokenomics;

    // Events
    event PumpRecorded(address indexed token, address indexed user, uint256 amount, uint256 multiplier);
    event RewardClaimed(address indexed user, uint256 amount);
    event StreakUpdated(address indexed user, address indexed token, uint256 streak, uint256 multiplier);

    constructor(address _rewardToken, address _tokenomics) {
        rewardToken = IERC20(_rewardToken);
        tokenomics = ITokenomics(_tokenomics);
        _initializeRewardTiers();
    }

    function recordPump(
        address token,
        address user,
        uint256 amount
    ) external returns (uint256 multiplier) {
        require(amount > 0, "Invalid amount");
        
        PumpStats storage stats = pumpStats[token][user];
        
        // Update pump streak
        if (block.timestamp <= stats.lastPumpTime + STREAK_RESET_TIME) {
            stats.pumpStreak = stats.pumpStreak >= MAX_STREAK ? MAX_STREAK : stats.pumpStreak + 1;
        } else {
            stats.pumpStreak = 1;
        }
        
        // Calculate multiplier based on tier and streak
        uint256 tierMultiplier = _getTierMultiplier(amount);
        uint256 streakBonus = (stats.pumpStreak * STREAK_BONUS);
        multiplier = tierMultiplier + streakBonus;
        
        // Cap multiplier
        if (multiplier > MAX_MULTIPLIER) {
            multiplier = MAX_MULTIPLIER;
        }
        
        stats.totalPumped += amount;
        stats.lastPumpTime = block.timestamp;
        stats.rewardMultiplier = multiplier;
        
        emit PumpRecorded(token, user, amount, multiplier);
        emit StreakUpdated(user, token, stats.pumpStreak, multiplier);
        
        return multiplier;
    }

    function claimRewards(address token) external {
        PumpStats storage stats = pumpStats[token][msg.sender];
        require(stats.totalPumped > 0, "No rewards");
        
        uint256 baseReward = (stats.totalPumped * stats.rewardMultiplier) / 100;
        uint256 fees = tokenomics.calculateTotalFees(baseReward);
        uint256 actualReward = baseReward - fees;
        
        // Reset stats after claim
        stats.totalPumped = 0;
        stats.rewardMultiplier = 0;
        
        require(rewardToken.transfer(msg.sender, actualReward), "Transfer failed");
        emit RewardClaimed(msg.sender, actualReward);
    }

    function getPumpStats(
        address token,
        address user
    ) external view returns (
        uint256 totalPumped,
        uint256 streak,
        uint256 multiplier
    ) {
        PumpStats storage stats = pumpStats[token][user];
        return (
            stats.totalPumped,
            stats.pumpStreak,
            stats.rewardMultiplier
        );
    }

    function _getTierMultiplier(uint256 amount) internal view returns (uint256) {
        uint256 multiplier = 100; // Base 1x
        
        for (uint256 i = 1; i <= 3; i++) {
            RewardTier storage tier = rewardTiers[i];
            if (amount >= tier.minPump) {
                multiplier = tier.multiplier;
            }
        }
        
        return multiplier;
    }

    function _initializeRewardTiers() internal {
        // Tier 1: 1.5x for 100+ tokens
        rewardTiers[1] = RewardTier(100 * 1e18, 150, 1 days);
        
        // Tier 2: 2x for 1000+ tokens
        rewardTiers[2] = RewardTier(1000 * 1e18, 200, 2 days);
        
        // Tier 3: 3x for 10000+ tokens
        rewardTiers[3] = RewardTier(10000 * 1e18, 300, 3 days);
    }
} 