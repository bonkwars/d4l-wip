// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface ICrossChainBridge {
    struct BridgeConfig {
        uint256 sourceChainId;
        uint256 targetChainId;
        address sourceToken;
        address targetToken;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 bridgeFee;
        bool paused;
    }

    struct BridgeRequest {
        uint256 nonce;
        address sender;
        address recipient;
        uint256 amount;
        uint256 timestamp;
        bool executed;
    }

    event BridgeInitiated(
        uint256 indexed sourceChainId,
        uint256 indexed targetChainId,
        address indexed sender,
        address recipient,
        uint256 amount,
        uint256 nonce
    );

    event BridgeCompleted(
        uint256 indexed sourceChainId,
        uint256 indexed targetChainId,
        address indexed recipient,
        uint256 amount,
        uint256 nonce
    );

    event BridgeConfigUpdated(
        uint256 indexed sourceChainId,
        uint256 indexed targetChainId,
        address sourceToken,
        address targetToken,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 bridgeFee
    );

    event BridgePaused(uint256 indexed sourceChainId, uint256 indexed targetChainId);
    event BridgeUnpaused(uint256 indexed sourceChainId, uint256 indexed targetChainId);

    /// @notice Initiates a bridge transfer to another chain
    /// @param targetChainId The target chain ID
    /// @param recipient The recipient address on the target chain
    /// @param amount The amount to bridge
    /// @return nonce The unique identifier for this bridge request
    function initiateBridge(
        uint256 targetChainId,
        address recipient,
        uint256 amount
    ) external payable returns (uint256 nonce);

    /// @notice Completes a bridge transfer on the target chain
    /// @param sourceChainId The source chain ID
    /// @param sender The sender address from the source chain
    /// @param recipient The recipient address on this chain
    /// @param amount The amount to bridge
    /// @param nonce The unique identifier for this bridge request
    /// @param signature The validator signature
    function completeBridge(
        uint256 sourceChainId,
        address sender,
        address recipient,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) external;

    /// @notice Updates the bridge configuration
    /// @param sourceChainId The source chain ID
    /// @param targetChainId The target chain ID
    /// @param config The new bridge configuration
    function updateBridgeConfig(
        uint256 sourceChainId,
        uint256 targetChainId,
        BridgeConfig calldata config
    ) external;

    /// @notice Pauses bridging between two chains
    /// @param sourceChainId The source chain ID
    /// @param targetChainId The target chain ID
    function pauseBridge(uint256 sourceChainId, uint256 targetChainId) external;

    /// @notice Unpauses bridging between two chains
    /// @param sourceChainId The source chain ID
    /// @param targetChainId The target chain ID
    function unpauseBridge(uint256 sourceChainId, uint256 targetChainId) external;

    /// @notice Gets the bridge configuration for a chain pair
    /// @param sourceChainId The source chain ID
    /// @param targetChainId The target chain ID
    function getBridgeConfig(uint256 sourceChainId, uint256 targetChainId)
        external
        view
        returns (BridgeConfig memory);

    /// @notice Gets a bridge request by nonce
    /// @param nonce The bridge request nonce
    function getBridgeRequest(uint256 nonce)
        external
        view
        returns (BridgeRequest memory);

    /// @notice Validates a bridge signature
    /// @param sourceChainId The source chain ID
    /// @param sender The sender address
    /// @param recipient The recipient address
    /// @param amount The amount being bridged
    /// @param nonce The bridge request nonce
    /// @param signature The validator signature
    function validateSignature(
        uint256 sourceChainId,
        address sender,
        address recipient,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) external view returns (bool);

    /// @notice Calculates the bridge fee for a given amount
    /// @param sourceChainId The source chain ID
    /// @param targetChainId The target chain ID
    /// @param amount The amount to bridge
    function calculateBridgeFee(
        uint256 sourceChainId,
        uint256 targetChainId,
        uint256 amount
    ) external view returns (uint256);
} 