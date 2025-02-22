// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface ITokenMetadata {
    struct TokenMetadata {
        string name;
        string symbol;
        string description;
        string image;
        string externalUrl;
        mapping(string => string) attributes;
    }

    event MetadataUpdated(address indexed token, string newUri);
    event AttributeAdded(address indexed token, string key, string value);

    /// @notice Sets the token metadata URI
    /// @param token The token address
    /// @param uri The IPFS URI of the metadata
    function setMetadataUri(address token, string calldata uri) external;

    /// @notice Gets the token metadata URI
    /// @param token The token address
    function getMetadataUri(address token) external view returns (string memory);

    /// @notice Adds a custom attribute to the token metadata
    /// @param token The token address
    /// @param key The attribute key
    /// @param value The attribute value
    function addAttribute(address token, string calldata key, string calldata value) external;

    /// @notice Gets a specific attribute value
    /// @param token The token address
    /// @param key The attribute key
    function getAttribute(address token, string calldata key) external view returns (string memory);

    /// @notice Validates metadata URI format
    /// @param uri The URI to validate
    /// @return isValid Whether the URI is valid
    function isValidMetadataUri(string calldata uri) external pure returns (bool);

    /// @notice Gets the IPFS gateway URL
    function getIpfsGateway() external view returns (string memory);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
} 