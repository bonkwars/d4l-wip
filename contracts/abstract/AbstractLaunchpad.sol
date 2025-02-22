// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "../interfaces/ILaunchpad.sol";
import "../interfaces/IWETH.sol";
import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "solmate/src/utils/FixedPointMathLib.sol";
import "solmate/src/utils/ReentrancyGuard.sol";
import "solmate/src/tokens/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../curve/curve.sol";
import "../constants/constants.sol";
import "../metadata/TokenMetadata.sol";
import "../fees/FeeHandler.sol";

abstract contract AbstractLaunchpad is ILaunchpad, Owned, ReentrancyGuard {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    // Constants for pump mechanics
    uint16 constant MAX_MOMENTUM = 10000; // 100% in basis points
    uint8 constant MAX_LEVEL = 10;
    uint32 constant MOMENTUM_DECAY_PERIOD = 1 hours;
    uint16 constant MOMENTUM_DECAY_RATE = 100; // 1% per hour in basis points
    uint16 constant MIN_PUMP_THRESHOLD = 500; // 5% in basis points

    // Vesting schedule struct
    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revocable;
        bool revoked;
    }

    // WETH address
    address public immutable WETH;

    // Packed storage for launch data
    mapping(address => LaunchConfig) private _launchConfigs;
    mapping(address => PumpMetrics) private _pumpMetrics;
    mapping(address => SocialMetrics) private _socialMetrics;
    
    // Vesting schedules
    mapping(uint256 => VestingSchedule) private _vestingSchedules;
    mapping(address => uint256[]) private _beneficiarySchedules;
    uint256 private _nextScheduleId;
    
    // Efficient mappings for user data
    mapping(address => mapping(address => bool)) private _whitelist;
    mapping(address => mapping(address => uint96)) private _contributions;
    mapping(address => mapping(address => uint96)) private _pendingRewards;
    mapping(address => mapping(address => uint32)) private _lastPumpTime;
    
    // Packed arrays for rankings
    mapping(address => address[]) private _topPumpers;
    mapping(address => uint96[]) private _pumpScores;

    // Add new state variables
    TokenMetadata public immutable metadataHandler;
    FeeHandler public immutable feeHandler;

    // Add validation constants
    uint256 private constant MIN_VESTING_PERIOD = 1 days;
    uint256 private constant MAX_VESTING_PERIOD = 365 days;
    uint256 private constant MIN_CLIFF_PERIOD = 0;
    uint256 private constant MAX_CLIFF_PERIOD = 30 days;
    uint256 private constant MAX_VESTING_SCHEDULES = 5;

    // Events
    event VestingScheduleCreated(
        uint256 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensVested(
        uint256 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingScheduleRevoked(
        uint256 indexed scheduleId,
        address indexed beneficiary
    );

    constructor(
        address _weth,
        address _metadataHandler,
        address _feeHandler
    ) Owned(msg.sender) {
        WETH = _weth;
        metadataHandler = TokenMetadata(_metadataHandler);
        feeHandler = FeeHandler(payable(_feeHandler));
    }

    receive() external payable {
        require(msg.sender == WETH, "Only WETH");
    }

    /// @notice Creates a new token launch
    function createLaunch(
        address token,
        LaunchConfig calldata config,
        string calldata metadataCid
    ) external payable override nonReentrant {
        require(token != address(0), "Invalid token");
        require(_launchConfigs[token].status == 0, "Launch exists");
        require(config.startTime > block.timestamp, "Invalid start");
        require(config.endTime > config.startTime, "Invalid end");
        require(config.hardCap >= config.softCap, "Invalid caps");
        require(msg.value == BASE_FEE, "Invalid fee");

        // Collect base fee
        feeHandler.collectBaseFee{value: msg.value}();

        // Store metadata
        metadataHandler.setMetadata(token, metadataCid);

        // Store launch config
        _launchConfigs[token] = config;
        _initializeMetrics(token);

        emit LaunchCreated(
            token,
            msg.sender,
            config.initialPrice,
            config.hardCap,
            config.startTime,
            config.endTime
        );
    }

    /// @notice Participates in a token launch
    function participate(
        address token,
        uint96 amount
    ) external payable override nonReentrant {
        LaunchConfig storage config = _launchConfigs[token];
        require(config.status == 1, "Not active");
        require(block.timestamp >= config.startTime, "Not started");
        require(block.timestamp <= config.endTime, "Ended");
        
        if (config.whitelistEnabled) {
            require(_whitelist[token][msg.sender], "Not whitelisted");
        }

        // Handle ETH to WETH conversion
        if (msg.value > 0) {
            IWETH(WETH).deposit{value: msg.value}();
            require(IWETH(WETH).transfer(address(this), msg.value), "WETH transfer failed");
        }

        _processParticipation(token, msg.sender, amount);
    }

    /// @notice Triggers a pump action
    function pump(
        address token,
        uint96 amount
    ) external override payable nonReentrant {
        require(_launchConfigs[token].status == 2, "Not launched");
        require(amount > 0, "Invalid amount");

        PumpMetrics storage metrics = _pumpMetrics[token];
        uint32 timeSinceLastPump = uint32(block.timestamp) - _lastPumpTime[token][msg.sender];
        
        // Update momentum with decay
        metrics.momentum = _calculateNewMomentum(
            metrics.momentum,
            timeSinceLastPump
        );

        // Handle ETH to WETH conversion if needed
        if (msg.value > 0) {
            IWETH(WETH).deposit{value: msg.value}();
            require(IWETH(WETH).transfer(address(this), msg.value), "WETH transfer failed");
        }

        // Process pump action
        _processPumpAction(token, msg.sender, amount, metrics);
    }

    /// @notice Records a social interaction
    function recordSocialAction(
        address token,
        string calldata actionType,
        bytes calldata proof
    ) external override {
        require(_verifySocialProof(token, actionType, proof), "Invalid proof");
        
        SocialMetrics storage metrics = _socialMetrics[token];
        uint16 score = _calculateSocialScore(actionType);
        
        _updateSocialMetrics(metrics, score);
        
        emit SocialInteraction(token, msg.sender, actionType, score);
    }

    /// @notice Claims pump rewards
    function claimPumpRewards(
        address token
    ) external override nonReentrant returns (uint96 amount) {
        amount = _pendingRewards[token][msg.sender];
        require(amount > 0, "No rewards");
        
        _pendingRewards[token][msg.sender] = 0;
        require(ERC20(token).transfer(msg.sender, amount), "Transfer failed");
        
        emit RewardDistributed(token, msg.sender, amount, "pump");
    }

    // View functions
    function getPumpMetrics(
        address token
    ) external view override returns (PumpMetrics memory) {
        return _pumpMetrics[token];
    }

    function getSocialMetrics(
        address token
    ) external view override returns (SocialMetrics memory) {
        return _socialMetrics[token];
    }

    function getLaunchInfo(
        address token
    ) external view override returns (LaunchConfig memory) {
        return _launchConfigs[token];
    }

    function getUserStats(
        address token,
        address user
    ) external view override returns (
        uint32 rank,
        uint96 score,
        uint96 rewards
    ) {
        rank = _calculateUserRank(token, user);
        score = _pumpScores[token][rank];
        rewards = _pendingRewards[token][user];
    }

    // Internal functions
    function _initializeMetrics(address token) internal virtual {
        _pumpMetrics[token] = PumpMetrics({
            totalVolume: 0,
            pumpScore: 0,
            uniqueTraders: 0,
            lastPumpTime: uint32(block.timestamp),
            momentum: 0,
            level: 1,
            isPumping: false
        });

        _socialMetrics[token] = SocialMetrics({
            holders: 0,
            interactions: 0,
            viralityScore: 0,
            communityScore: 0,
            tier: 1,
            verified: false
        });
    }

    function _calculateNewMomentum(
        uint16 currentMomentum,
        uint32 timePassed
    ) internal pure returns (uint16) {
        if (timePassed == 0) return currentMomentum;
        
        uint32 decayPeriods = timePassed / MOMENTUM_DECAY_PERIOD;
        uint16 decayAmount = uint16(decayPeriods * MOMENTUM_DECAY_RATE);
        
        return currentMomentum > decayAmount ? 
            currentMomentum - decayAmount : 0;
    }

    function _processPumpAction(
        address token,
        address user,
        uint96 amount,
        PumpMetrics storage metrics
    ) internal virtual {
        // Update metrics
        metrics.totalVolume += amount;
        metrics.pumpScore += _calculatePumpScore(amount, metrics.momentum);
        
        // Update momentum
        uint16 newMomentum = uint16(
            (uint32(metrics.momentum) + (amount * 100 / metrics.totalVolume))
            % MAX_MOMENTUM
        );
        metrics.momentum = newMomentum;

        // Update level if threshold reached
        if (newMomentum > MIN_PUMP_THRESHOLD && 
            metrics.level < MAX_LEVEL) {
            metrics.level++;
        }

        // Update user data
        _lastPumpTime[token][user] = uint32(block.timestamp);
        _updateRankings(token, user, metrics.pumpScore);

        emit PumpAction(
            token,
            user,
            amount,
            newMomentum,
            metrics.level
        );
    }

    function _calculatePumpScore(
        uint96 amount,
        uint16 momentum
    ) internal pure virtual returns (uint96) {
        return amount * (10000 + momentum) / 10000;
    }

    function _updateRankings(
        address token,
        address user,
        uint96 score
    ) internal virtual {
        // Implementation specific
    }

    function _calculateUserRank(
        address token,
        address user
    ) internal view virtual returns (uint32) {
        // Implementation specific
        return 0;
    }

    function _calculateSocialScore(
        string calldata actionType
    ) internal pure virtual returns (uint16) {
        // Implementation specific
        return 0;
    }

    function _updateSocialMetrics(
        SocialMetrics storage metrics,
        uint16 score
    ) internal virtual {
        metrics.interactions++;
        metrics.communityScore = uint16(
            (uint32(metrics.communityScore) + score) / 2
        );
    }

    function _verifySocialProof(
        address token,
        string calldata actionType,
        bytes calldata proof
    ) internal view virtual returns (bool) {
        // Implementation specific
        return false;
    }

    function _processParticipation(
        address token,
        address participant,
        uint96 amount
    ) internal virtual {
        // Implementation specific
    }

    /// @notice Creates a new vesting schedule
    function createVestingSchedule(
        address token,
        address beneficiary,
        uint256 amount,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 startTime
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Invalid amount");
        require(cliffDuration >= MIN_CLIFF_PERIOD && cliffDuration <= MAX_CLIFF_PERIOD, "Invalid cliff");
        require(vestingDuration >= MIN_VESTING_PERIOD && vestingDuration <= MAX_VESTING_PERIOD, "Invalid duration");
        require(startTime >= block.timestamp, "Invalid start time");
        
        // Check max schedules per beneficiary
        require(
            _beneficiarySchedules[beneficiary].length < MAX_VESTING_SCHEDULES,
            "Too many schedules"
        );

        uint256 scheduleId = _nextScheduleId++;
        
        _vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: true,
            revoked: false
        });

        _beneficiarySchedules[beneficiary].push(scheduleId);

        emit VestingScheduleCreated(
            scheduleId,
            beneficiary,
            amount,
            startTime,
            cliffDuration,
            vestingDuration
        );
    }

    /// @notice Gets the number of vesting schedules for a beneficiary
    function getVestingScheduleCount(address beneficiary) public view returns (uint256) {
        return _beneficiarySchedules[beneficiary].length;
    }

    /// @notice Gets a vesting schedule by ID
    function getVestingSchedule(uint256 scheduleId) public view returns (VestingSchedule memory) {
        return _vestingSchedules[scheduleId];
    }

    /// @notice Calculates the vested amount for a schedule
    function _calculateVestedAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        if (schedule.revoked) {
            return schedule.releasedAmount;
        }

        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }

    /// @notice Releases vested tokens for a schedule
    function releaseVestedTokens(address token, uint256 scheduleId) external nonReentrant {
        VestingSchedule storage schedule = _vestingSchedules[scheduleId];
        require(schedule.beneficiary == msg.sender, "Not beneficiary");
        require(block.timestamp >= schedule.startTime, "Not started");
        
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        uint256 claimableAmount = vestedAmount - schedule.releasedAmount;
        require(claimableAmount > 0, "Nothing to claim");

        schedule.releasedAmount = schedule.releasedAmount + claimableAmount;
        
        require(
            ERC20(token).transfer(msg.sender, claimableAmount),
            "Transfer failed"
        );

        emit TokensVested(scheduleId, msg.sender, claimableAmount);
    }

    /// @notice Revokes a vesting schedule
    function revokeVestingSchedule(uint256 scheduleId) external onlyOwner {
        VestingSchedule storage schedule = _vestingSchedules[scheduleId];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        schedule.revoked = true;
        emit VestingScheduleRevoked(scheduleId, schedule.beneficiary);
    }
} 