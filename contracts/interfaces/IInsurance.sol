// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IInsurance {
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

    event PoolCreated(CoverageType indexed coverageType, uint256 capacity, uint256 premiumRate);
    event CoveragePurchased(uint256 indexed coverageId, address indexed holder, CoverageType coverageType, uint256 amount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed coverageId, uint256 amount);
    event ClaimProcessed(uint256 indexed claimId, ClaimStatus status, uint256 amount);
    event StakeAdded(address indexed staker, uint256 amount);
    event StakeWithdrawn(address indexed staker, uint256 amount);
    event PremiumDistributed(uint256 amount);

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
    ) external returns (uint256);

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
    ) external returns (uint256);

    /**
     * @notice Stakes tokens to provide insurance capacity
     * @param amount Amount to stake
     */
    function stake(uint256 amount) external;

    /**
     * @notice Withdraws staked tokens
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Processes an insurance claim (admin only)
     * @param claimId The ID of the claim
     * @param status New status of the claim
     */
    function processClaim(uint256 claimId, ClaimStatus status) external;

    /**
     * @notice Gets all coverages for a user
     * @param user Address of the user
     * @return coverageIds Array of coverage IDs
     */
    function getUserCoverages(address user) external view returns (uint256[] memory);

    /**
     * @notice Gets details of an insurance pool
     * @param coverageType Type of coverage
     * @return pool The pool details
     */
    function pools(CoverageType coverageType) external view returns (InsurancePool memory);

    /**
     * @notice Gets details of a coverage
     * @param coverageId The ID of the coverage
     * @return coverage The coverage details
     */
    function coverages(uint256 coverageId) external view returns (Coverage memory);

    /**
     * @notice Gets details of a claim
     * @param claimId The ID of the claim
     * @return claim The claim details
     */
    function claims(uint256 claimId) external view returns (Claim memory);

    /**
     * @notice Gets staked balance of a user
     * @param user Address of the user
     * @return balance The staked balance
     */
    function stakedBalances(address user) external view returns (uint256);
} 