// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface IFeeDistributor {
    struct FeeConfig {
        uint16 stakingShare;     // 2 bytes - Share for staking rewards (basis points)
        uint16 treasuryShare;    // 2 bytes - Share for treasury (basis points)
        uint16 burnShare;        // 2 bytes - Share to burn (basis points)
        uint16 lpShare;          // 2 bytes - Share for LP providers (basis points)
        uint8 status;           // 1 byte  - Configuration status
        uint8 reserved;         // 1 byte  - Reserved for future use
    }

    struct EpochInfo {
        uint32 startTime;       // 4 bytes - Epoch start time
        uint32 endTime;         // 4 bytes - Epoch end time
        uint96 totalFees;       // 12 bytes - Total fees collected
        uint96 distributedFees; // 12 bytes - Fees already distributed
        bool finalized;        // 1 byte  - Whether epoch is finalized
        uint8 reserved;        // 1 byte  - Reserved for future use
    }

    struct UserClaim {
        uint32 lastClaimTime;   // 4 bytes - Last claim timestamp
        uint32 epochsClaimed;   // 4 bytes - Number of epochs claimed
        uint96 totalClaimed;    // 12 bytes - Total amount claimed
        bool whitelisted;      // 1 byte  - Whether user is whitelisted
        uint8 reserved;        // 1 byte  - Reserved for future use
    }

    event FeeReceived(
        address indexed token,
        uint96 amount,
        uint32 epoch
    );

    event FeeDistributed(
        uint32 indexed epoch,
        uint96 stakingAmount,
        uint96 treasuryAmount,
        uint96 burnAmount,
        uint96 lpAmount
    );

    event UserClaimed(
        address indexed user,
        uint32 indexed epoch,
        uint96 amount
    );

    event ConfigUpdated(
        uint16 stakingShare,
        uint16 treasuryShare,
        uint16 burnShare,
        uint16 lpShare
    );

    /// @notice Receives fees from trading
    /// @param token Token address
    /// @param amount Fee amount
    function receiveFees(address token, uint96 amount) external;

    /// @notice Distributes fees for an epoch
    /// @param epoch Epoch number
    function distributeFees(uint32 epoch) external;

    /// @notice Claims fees for a user
    /// @param user User address
    /// @param epochs Array of epoch numbers to claim
    /// @return amount Total amount claimed
    function claimFees(address user, uint32[] calldata epochs) external returns (uint96 amount);

    /// @notice Gets claimable fees for a user
    /// @param user User address
    /// @param epoch Epoch number
    function getClaimableFees(address user, uint32 epoch) external view returns (uint96);

    /// @notice Gets information about an epoch
    /// @param epoch Epoch number
    function getEpochInfo(uint32 epoch) external view returns (EpochInfo memory);

    /// @notice Gets claim information for a user
    /// @param user User address
    function getUserClaim(address user) external view returns (UserClaim memory);

    /// @notice Gets the current fee configuration
    function getFeeConfig() external view returns (FeeConfig memory);

    /// @notice Updates the fee configuration
    /// @param config New fee configuration
    function updateFeeConfig(FeeConfig calldata config) external;

    /// @notice Gets the current epoch number
    function getCurrentEpoch() external view returns (uint32);

    /// @notice Gets total fees collected in an epoch
    /// @param epoch Epoch number
    function getEpochFees(uint32 epoch) external view returns (uint96);

    /// @notice Checks if an epoch is finalized
    /// @param epoch Epoch number
    function isEpochFinalized(uint32 epoch) external view returns (bool);

    /// @notice Gets total fees distributed to date
    function getTotalDistributed() external view returns (uint96);
} 