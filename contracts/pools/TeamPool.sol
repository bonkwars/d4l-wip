// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/ITokenomics.sol";

/**
 * @title TeamPool
 * @notice Manages team token distribution with vesting schedules and performance metrics
 */
contract TeamPool is Ownable, ReentrancyGuard, Pausable {
    // Structs
    struct VestingSchedule {
        uint256 totalAmount;        // Total amount to vest
        uint256 startTime;          // Start of vesting period
        uint256 cliffDuration;      // Cliff period in seconds
        uint256 vestingDuration;    // Total vesting duration in seconds
        uint256 releasedAmount;     // Amount already released
        uint256 lastReleaseTime;    // Last token release timestamp
        bool revocable;             // Whether schedule can be revoked
        bool revoked;               // Whether schedule has been revoked
        uint256 performanceMultiplier; // Performance-based multiplier (100 = 1x)
    }

    struct TeamMember {
        bool isActive;
        uint256[] scheduleIds;      // Array of vesting schedule IDs
        uint256 totalAllocated;     // Total tokens allocated
        uint256 totalClaimed;       // Total tokens claimed
        uint256 performanceScore;   // Current performance score (0-100)
    }

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_VESTING_DURATION = 180 days;
    uint256 public constant MAX_VESTING_DURATION = 1460 days; // 4 years
    uint256 public constant MAX_CLIFF_DURATION = 365 days;
    uint256 public constant PERFORMANCE_UPDATE_COOLDOWN = 30 days;

    // State variables
    mapping(address => TeamMember) public teamMembers;
    mapping(uint256 => VestingSchedule) public vestingSchedules;
    uint256 public nextScheduleId;
    uint256 public totalTeamMembers;
    uint256 public totalAllocated;
    uint256 public totalVested;

    address public immutable distributor;
    IERC20 public immutable rewardToken;

    // Events
    event TeamMemberAdded(address indexed member);
    event VestingScheduleCreated(
        address indexed member,
        uint256 indexed scheduleId,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );
    event TokensVested(address indexed member, uint256 indexed scheduleId, uint256 amount);
    event VestingScheduleRevoked(uint256 indexed scheduleId);
    event PerformanceUpdated(address indexed member, uint256 oldScore, uint256 newScore);
    event EmergencyWithdrawn(address indexed token, uint256 amount, address recipient);

    // Modifiers
    modifier onlyDistributor() {
        require(msg.sender == distributor, "Only distributor");
        _;
    }

    modifier onlyTeamMember() {
        require(teamMembers[msg.sender].isActive, "Not team member");
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
     * @notice Adds a new team member
     */
    function addTeamMember(address member) external onlyOwner {
        require(member != address(0), "Invalid address");
        require(!teamMembers[member].isActive, "Already team member");

        teamMembers[member] = TeamMember({
            isActive: true,
            scheduleIds: new uint256[](0),
            totalAllocated: 0,
            totalClaimed: 0,
            performanceScore: 100 // Start with base performance
        });

        totalTeamMembers++;
        emit TeamMemberAdded(member);
    }

    /**
     * @notice Creates a new vesting schedule for a team member
     */
    function createVestingSchedule(
        address member,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    ) external onlyOwner {
        require(teamMembers[member].isActive, "Not team member");
        require(amount > 0, "Zero amount");
        require(vestingDuration >= MIN_VESTING_DURATION, "Vesting too short");
        require(vestingDuration <= MAX_VESTING_DURATION, "Vesting too long");
        require(cliffDuration <= MAX_CLIFF_DURATION, "Cliff too long");
        require(startTime >= block.timestamp, "Invalid start time");

        uint256 scheduleId = nextScheduleId++;
        vestingSchedules[scheduleId] = VestingSchedule({
            totalAmount: amount,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            releasedAmount: 0,
            lastReleaseTime: startTime,
            revocable: revocable,
            revoked: false,
            performanceMultiplier: 100
        });

        teamMembers[member].scheduleIds.push(scheduleId);
        teamMembers[member].totalAllocated += amount;
        totalAllocated += amount;

        emit VestingScheduleCreated(
            member,
            scheduleId,
            amount,
            startTime,
            cliffDuration,
            vestingDuration
        );
    }

    /**
     * @notice Claims vested tokens for a specific schedule
     */
    function claimVested(uint256 scheduleId) external nonReentrant onlyTeamMember {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(!schedule.revoked, "Schedule revoked");
        require(
            block.timestamp >= schedule.startTime + schedule.cliffDuration,
            "Cliff period active"
        );

        uint256 vestedAmount = _calculateVestedAmount(scheduleId);
        require(vestedAmount > 0, "Nothing to claim");

        schedule.releasedAmount += vestedAmount;
        schedule.lastReleaseTime = block.timestamp;
        teamMembers[msg.sender].totalClaimed += vestedAmount;
        totalVested += vestedAmount;

        require(rewardToken.transfer(msg.sender, vestedAmount), "Transfer failed");
        emit TokensVested(msg.sender, scheduleId, vestedAmount);
    }

    /**
     * @notice Updates performance score for a team member
     */
    function updatePerformance(
        address member,
        uint256 newScore
    ) external onlyOwner {
        require(teamMembers[member].isActive, "Not team member");
        require(newScore <= 100, "Invalid score");
        
        uint256 oldScore = teamMembers[member].performanceScore;
        teamMembers[member].performanceScore = newScore;

        // Update performance multipliers for all active schedules
        uint256[] storage scheduleIds = teamMembers[member].scheduleIds;
        for (uint256 i = 0; i < scheduleIds.length; i++) {
            VestingSchedule storage schedule = vestingSchedules[scheduleIds[i]];
            if (!schedule.revoked) {
                schedule.performanceMultiplier = newScore;
            }
        }

        emit PerformanceUpdated(member, oldScore, newScore);
    }

    /**
     * @notice Revokes a vesting schedule
     */
    function revokeSchedule(uint256 scheduleId) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        schedule.revoked = true;
        emit VestingScheduleRevoked(scheduleId);
    }

    /**
     * @notice Calculates vested amount for a schedule
     */
    function _calculateVestedAmount(uint256 scheduleId) internal view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        if (timeFromStart >= schedule.vestingDuration) {
            return schedule.totalAmount - schedule.releasedAmount;
        }

        uint256 vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
        vestedAmount = (vestedAmount * schedule.performanceMultiplier) / 100;
        return vestedAmount - schedule.releasedAmount;
    }

    /**
     * @notice Distributes new tokens from the automated distributor
     */
    function distributeRewards() external payable onlyDistributor nonReentrant whenNotPaused {
        require(msg.value > 0, "Zero value");
        // Additional distribution logic can be added here
    }

    /**
     * @notice Emergency withdrawal of stuck funds
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