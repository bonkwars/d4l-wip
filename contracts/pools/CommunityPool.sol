// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/ITokenomics.sol";

/**
 * @title CommunityPool
 * @notice Manages community rewards and incentives with tiered distribution
 */
contract CommunityPool is Ownable, ReentrancyGuard, Pausable {
    // Structs
    struct Tier {
        uint256 minStake;      // Minimum stake required for tier
        uint256 rewardShare;   // Share of rewards (in basis points, 100 = 1%)
        uint256 lockPeriod;    // Lock period in seconds
        uint256 maxParticipants; // Maximum participants in tier
    }

    struct Participant {
        uint256 stakedAmount;
        uint256 lastStakeTime;
        uint256 lastClaimTime;
        uint256 currentTier;
        uint256 rewardDebt;
        bool isActive;
    }

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_STAKE_PERIOD = 7 days;
    uint256 public constant MAX_STAKE_PERIOD = 365 days;
    uint256 public constant CLAIM_COOLDOWN = 1 days;
    uint256 public constant MAX_TIERS = 5;

    // State variables
    mapping(uint256 => Tier) public tiers;
    mapping(address => Participant) public participants;
    mapping(uint256 => uint256) public tierParticipantCount;
    
    uint256 public totalParticipants;
    uint256 public totalStaked;
    uint256 public accRewardPerShare;
    uint256 public lastUpdateTime;
    uint256 public totalTiers;

    address public immutable distributor;
    IERC20 public immutable rewardToken;

    // Events
    event TierAdded(uint256 indexed tierId, uint256 minStake, uint256 rewardShare, uint256 lockPeriod);
    event Staked(address indexed user, uint256 amount, uint256 tier);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event TierUpgraded(address indexed user, uint256 oldTier, uint256 newTier);
    event EmergencyWithdrawn(address indexed token, uint256 amount, address recipient);

    // Modifiers
    modifier onlyDistributor() {
        require(msg.sender == distributor, "Only distributor");
        _;
    }

    constructor(
        address _distributor,
        address _rewardToken
    ) Ownable(msg.sender) {
        require(_distributor != address(0), "Invalid distributor");
        require(_rewardToken != address(0), "Invalid reward token");
        distributor = _distributor;
        rewardToken = IERC20(_rewardToken);
    }

    /**
     * @notice Adds a new tier with specified parameters
     */
    function addTier(
        uint256 minStake,
        uint256 rewardShare,
        uint256 lockPeriod,
        uint256 maxParticipants
    ) external onlyOwner {
        require(totalTiers < MAX_TIERS, "Max tiers reached");
        require(rewardShare <= BASIS_POINTS, "Invalid reward share");
        require(lockPeriod >= MIN_STAKE_PERIOD && lockPeriod <= MAX_STAKE_PERIOD, "Invalid lock period");
        require(maxParticipants > 0, "Invalid max participants");

        uint256 tierId = totalTiers++;
        tiers[tierId] = Tier({
            minStake: minStake,
            rewardShare: rewardShare,
            lockPeriod: lockPeriod,
            maxParticipants: maxParticipants
        });

        emit TierAdded(tierId, minStake, rewardShare, lockPeriod);
    }

    /**
     * @notice Stakes tokens to participate in rewards
     */
    function stake(uint256 amount, uint256 tierId) external nonReentrant whenNotPaused {
        require(amount > 0, "Zero amount");
        require(tierId < totalTiers, "Invalid tier");
        
        Tier storage tier = tiers[tierId];
        require(amount >= tier.minStake, "Insufficient stake for tier");
        require(tierParticipantCount[tierId] < tier.maxParticipants, "Tier full");

        Participant storage participant = participants[msg.sender];
        
        if (participant.isActive) {
            // Update existing stake
            _updateRewards(msg.sender);
            totalStaked += amount;
        } else {
            // New participant
            participant.isActive = true;
            participant.currentTier = tierId;
            participant.lastClaimTime = block.timestamp;
            totalParticipants++;
            tierParticipantCount[tierId]++;
            totalStaked += amount;
        }

        participant.stakedAmount += amount;
        participant.lastStakeTime = block.timestamp;
        
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit Staked(msg.sender, amount, tierId);
    }

    /**
     * @notice Unstakes tokens after lock period
     */
    function unstake(uint256 amount) external nonReentrant {
        Participant storage participant = participants[msg.sender];
        require(participant.isActive, "Not staked");
        require(amount > 0 && amount <= participant.stakedAmount, "Invalid amount");
        
        Tier storage tier = tiers[participant.currentTier];
        require(
            block.timestamp >= participant.lastStakeTime + tier.lockPeriod,
            "Lock period active"
        );

        _updateRewards(msg.sender);
        
        participant.stakedAmount -= amount;
        totalStaked -= amount;

        if (participant.stakedAmount == 0) {
            tierParticipantCount[participant.currentTier]--;
            totalParticipants--;
            participant.isActive = false;
        }

        require(rewardToken.transfer(msg.sender, amount), "Transfer failed");
        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Claims available rewards
     */
    function claimRewards() external nonReentrant whenNotPaused {
        require(
            block.timestamp >= participants[msg.sender].lastClaimTime + CLAIM_COOLDOWN,
            "Cooldown active"
        );
        
        uint256 reward = _updateRewards(msg.sender);
        require(reward > 0, "No rewards");
        
        participants[msg.sender].lastClaimTime = block.timestamp;
        participants[msg.sender].rewardDebt = 0;
        
        require(rewardToken.transfer(msg.sender, reward), "Transfer failed");
        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @notice Upgrades participant tier if eligible
     */
    function upgradeTier(uint256 newTierId) external nonReentrant whenNotPaused {
        require(newTierId < totalTiers, "Invalid tier");
        
        Participant storage participant = participants[msg.sender];
        require(participant.isActive, "Not staked");
        require(newTierId > participant.currentTier, "Can only upgrade");
        
        Tier storage newTier = tiers[newTierId];
        require(participant.stakedAmount >= newTier.minStake, "Insufficient stake");
        require(tierParticipantCount[newTierId] < newTier.maxParticipants, "Tier full");

        _updateRewards(msg.sender);
        
        uint256 oldTier = participant.currentTier;
        tierParticipantCount[oldTier]--;
        tierParticipantCount[newTierId]++;
        participant.currentTier = newTierId;
        participant.lastStakeTime = block.timestamp;

        emit TierUpgraded(msg.sender, oldTier, newTierId);
    }

    /**
     * @notice Distributes rewards from the automated distributor
     */
    function distributeRewards() external payable onlyDistributor nonReentrant whenNotPaused {
        require(totalStaked > 0, "No stakers");
        require(msg.value > 0, "Zero value");
        
        uint256 rewardPerShare = (msg.value * BASIS_POINTS) / totalStaked;
        accRewardPerShare += rewardPerShare;
        lastUpdateTime = block.timestamp;
    }

    /**
     * @notice Updates rewards for a participant
     */
    function _updateRewards(address user) internal returns (uint256) {
        Participant storage participant = participants[user];
        if (!participant.isActive) return 0;
        
        uint256 pending = (participant.stakedAmount * accRewardPerShare / BASIS_POINTS) -
            participant.rewardDebt;
            
        if (pending > 0) {
            Tier storage tier = tiers[participant.currentTier];
            uint256 reward = (pending * tier.rewardShare) / BASIS_POINTS;
            participant.rewardDebt = (participant.stakedAmount * accRewardPerShare) / BASIS_POINTS;
            return reward;
        }
        return 0;
    }

    /**
     * @notice Emergency withdrawal of stuck funds by owner
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        
        if (token == address(0)) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            require(IERC20(token).transfer(recipient, amount), "Token transfer failed");
        }

        emit EmergencyWithdrawn(token, amount, recipient);
    }

    /**
     * @notice Pauses all non-essential functions
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses all functions
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {
        require(msg.sender == distributor, "Only distributor");
    }
} 