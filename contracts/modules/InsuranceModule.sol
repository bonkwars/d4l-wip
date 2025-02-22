// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IContractRegistry.sol";
import "../interfaces/IInsurance.sol";

/**
 * @title InsuranceModule
 * @notice Provides insurance coverage for various DeFi risks
 */
contract InsuranceModule is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    // State variables
    IContractRegistry public registry;
    
    struct InsurancePool {
        uint256 totalCapacity;
        uint256 totalStaked;
        uint256 premiumRate;
        uint256 coverageLimit;
        uint256 minStakeTime;
        uint256 claimDelay;
        bool active;
    }

    struct Coverage {
        address holder;
        uint256 amount;
        uint256 premium;
        uint256 startTime;
        uint256 endTime;
        CoverageType coverageType;
        CoverageStatus status;
    }

    struct Claim {
        uint256 coverageId;
        uint256 amount;
        uint256 timestamp;
        string evidence;
        ClaimStatus status;
    }

    enum CoverageType {
        IMPERMANENT_LOSS,
        SMART_CONTRACT,
        FLASH_LOAN,
        ORACLE_FAILURE
    }

    enum CoverageStatus {
        ACTIVE,
        EXPIRED,
        CLAIMED
    }

    enum ClaimStatus {
        PENDING,
        APPROVED,
        REJECTED
    }

    // Mappings
    mapping(CoverageType => InsurancePool) public pools;
    mapping(uint256 => Coverage) public coverages;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userCoverages;
    mapping(address => uint256) public stakedBalances;
    
    // Counters
    uint256 private _coverageCounter;
    uint256 private _claimCounter;

    // Constants
    uint256 public constant MIN_COVERAGE_DURATION = 7 days;
    uint256 public constant MAX_COVERAGE_DURATION = 365 days;
    uint256 public constant CLAIM_REVIEW_PERIOD = 3 days;

    // Events
    event PoolCreated(CoverageType indexed coverageType, uint256 capacity, uint256 premiumRate);
    event CoveragePurchased(uint256 indexed coverageId, address indexed holder, CoverageType coverageType, uint256 amount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed coverageId, uint256 amount);
    event ClaimProcessed(uint256 indexed claimId, ClaimStatus status, uint256 amount);
    event StakeAdded(address indexed staker, uint256 amount);
    event StakeWithdrawn(address indexed staker, uint256 amount);
    event PremiumDistributed(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _registry) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_registry != address(0), "Invalid registry");
        registry = IContractRegistry(_registry);

        // Initialize default pools
        _initializePool(CoverageType.IMPERMANENT_LOSS, 1000e18, 5); // 0.5% premium
        _initializePool(CoverageType.SMART_CONTRACT, 2000e18, 10);  // 1% premium
        _initializePool(CoverageType.FLASH_LOAN, 1500e18, 15);      // 1.5% premium
        _initializePool(CoverageType.ORACLE_FAILURE, 1000e18, 20);  // 2% premium
    }

    /**
     * @notice Purchases insurance coverage
     * @param coverageType Type of coverage
     * @param amount Amount to insure
     * @param duration Duration of coverage
     * @return coverageId The ID of the created coverage
     */
    function purchaseCoverage(
        CoverageType coverageType,
        uint256 amount,
        uint256 duration
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(duration >= MIN_COVERAGE_DURATION && duration <= MAX_COVERAGE_DURATION, "Invalid duration");
        
        InsurancePool storage pool = pools[coverageType];
        require(pool.active, "Pool inactive");
        require(amount <= pool.coverageLimit, "Exceeds coverage limit");
        require(pool.totalStaked >= amount, "Insufficient capacity");

        uint256 premium = _calculatePremium(amount, duration, pool.premiumRate);
        uint256 coverageId = _coverageCounter++;

        Coverage memory coverage = Coverage({
            holder: msg.sender,
            amount: amount,
            premium: premium,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            coverageType: coverageType,
            status: CoverageStatus.ACTIVE
        });

        coverages[coverageId] = coverage;
        userCoverages[msg.sender].push(coverageId);

        // Transfer premium
        IERC20(registry.getContractAddressByName("D4L_TOKEN")).transferFrom(
            msg.sender,
            address(this),
            premium
        );

        emit CoveragePurchased(coverageId, msg.sender, coverageType, amount);
        
        return coverageId;
    }

    /**
     * @notice Submits an insurance claim
     * @param coverageId The ID of the coverage
     * @param amount Amount to claim
     * @param evidence IPFS hash of evidence
     * @return claimId The ID of the created claim
     */
    function submitClaim(
        uint256 coverageId,
        uint256 amount,
        string calldata evidence
    ) external nonReentrant returns (uint256) {
        Coverage storage coverage = coverages[coverageId];
        require(coverage.holder == msg.sender, "Not coverage holder");
        require(coverage.status == CoverageStatus.ACTIVE, "Coverage not active");
        require(block.timestamp <= coverage.endTime, "Coverage expired");
        require(amount <= coverage.amount, "Exceeds coverage amount");

        uint256 claimId = _claimCounter++;
        
        claims[claimId] = Claim({
            coverageId: coverageId,
            amount: amount,
            timestamp: block.timestamp,
            evidence: evidence,
            status: ClaimStatus.PENDING
        });

        emit ClaimSubmitted(claimId, coverageId, amount);
        
        return claimId;
    }

    /**
     * @notice Stakes tokens to provide insurance capacity
     * @param amount Amount to stake
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");

        stakedBalances[msg.sender] += amount;
        
        // Update all pools' totalStaked
        for (uint i = 0; i < 4; i++) {
            pools[CoverageType(i)].totalStaked += amount;
        }
        
        IERC20(registry.getContractAddressByName("D4L_TOKEN")).transferFrom(
            msg.sender,
            address(this),
            amount
        );

        emit StakeAdded(msg.sender, amount);
    }

    /**
     * @notice Withdraws staked tokens
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0 && amount <= stakedBalances[msg.sender], "Invalid amount");
        require(block.timestamp >= _getLastStakeTime(msg.sender) + MIN_COVERAGE_DURATION, "Stake locked");

        stakedBalances[msg.sender] -= amount;
        
        // Update all pools' totalStaked
        for (uint i = 0; i < 4; i++) {
            pools[CoverageType(i)].totalStaked -= amount;
        }
        
        IERC20(registry.getContractAddressByName("D4L_TOKEN")).transfer(
            msg.sender,
            amount
        );

        emit StakeWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Processes an insurance claim (admin only)
     * @param claimId The ID of the claim
     * @param status New status of the claim
     */
    function processClaim(uint256 claimId, ClaimStatus status) external onlyOwner {
        Claim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.PENDING, "Claim not pending");
        require(block.timestamp <= claim.timestamp + CLAIM_REVIEW_PERIOD, "Review period expired");

        claim.status = status;
        
        if (status == ClaimStatus.APPROVED) {
            Coverage storage coverage = coverages[claim.coverageId];
            coverage.status = CoverageStatus.CLAIMED;
            
            // Transfer claim amount
            IERC20(registry.getContractAddressByName("D4L_TOKEN")).transfer(
                coverage.holder,
                claim.amount
            );
        }

        emit ClaimProcessed(claimId, status, claim.amount);
    }

    /**
     * @notice Gets all coverages for a user
     * @param user Address of the user
     * @return coverageIds Array of coverage IDs
     */
    function getUserCoverages(address user) external view returns (uint256[] memory) {
        return userCoverages[user];
    }

    // Internal functions

    function _initializePool(
        CoverageType coverageType,
        uint256 coverageLimit,
        uint256 premiumRate
    ) internal {
        pools[coverageType] = InsurancePool({
            totalCapacity: 0,
            totalStaked: 0,
            premiumRate: premiumRate,
            coverageLimit: coverageLimit,
            minStakeTime: MIN_COVERAGE_DURATION,
            claimDelay: CLAIM_REVIEW_PERIOD,
            active: true
        });

        emit PoolCreated(coverageType, coverageLimit, premiumRate);
    }

    function _calculatePremium(
        uint256 amount,
        uint256 duration,
        uint256 rate
    ) internal pure returns (uint256) {
        return (amount * duration * rate) / (365 days * 1000);
    }

    function _getLastStakeTime(address staker) internal view returns (uint256) {
        // Implementation needed: track last stake time
        return 0;
    }
} 