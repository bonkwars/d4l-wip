// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface ITokenRegistry {
    struct TokenInfo {
        address token;
        address creator;
        string name;
        string symbol;
        uint256 totalSupply;
        uint256 creationTime;
        string metadataUri;
        bool verified;
    }

    event TokenRegistered(
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 totalSupply
    );

    event TokenVerified(address indexed token, bool verified);
    event TokenMetadataUpdated(address indexed token, string newUri);
    event CreatorBlacklisted(address indexed creator, string reason);

    /// @notice Registers a new token in the registry
    /// @param token Token address
    /// @param creator Creator address
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param totalSupply Total supply
    /// @param metadataUri IPFS metadata URI
    function registerToken(
        address token,
        address creator,
        string calldata name,
        string calldata symbol,
        uint256 totalSupply,
        string calldata metadataUri
    ) external;

    /// @notice Updates token verification status
    /// @param token Token address
    /// @param verified New verification status
    function setTokenVerification(address token, bool verified) external;

    /// @notice Updates token metadata URI
    /// @param token Token address
    /// @param newUri New metadata URI
    function updateTokenMetadata(address token, string calldata newUri) external;

    /// @notice Blacklists a creator address
    /// @param creator Creator address
    /// @param reason Reason for blacklisting
    function blacklistCreator(address creator, string calldata reason) external;

    /// @notice Gets information about a token
    /// @param token Token address
    function getTokenInfo(address token) external view returns (TokenInfo memory);

    /// @notice Gets all tokens created by an address
    /// @param creator Creator address
    function getTokensByCreator(address creator) external view returns (address[] memory);

    /// @notice Gets all verified tokens
    function getVerifiedTokens() external view returns (address[] memory);

    /// @notice Checks if a creator is blacklisted
    /// @param creator Creator address
    function isCreatorBlacklisted(address creator) external view returns (bool);

    /// @notice Gets the total number of registered tokens
    function getTotalTokens() external view returns (uint256);

    /// @notice Gets token addresses by page
    /// @param page Page number (0-based)
    /// @param pageSize Number of items per page
    function getTokensByPage(uint256 page, uint256 pageSize) external view returns (address[] memory);
} 