// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ITokenRegistry.sol";

abstract contract AbstractTokenRegistry is Ownable, ITokenRegistry {
    // Mapping from token address to token info
    mapping(address => TokenInfo) private _tokenInfo;
    
    // Mapping from creator to their tokens
    mapping(address => address[]) private _creatorTokens;
    
    // Array of all tokens
    address[] private _allTokens;
    
    // Array of verified tokens
    address[] private _verifiedTokens;
    
    // Mapping of blacklisted creators
    mapping(address => bool) private _blacklistedCreators;

    constructor() Ownable(msg.sender) {}

    /// @notice Registers a new token in the registry
    function registerToken(
        address token,
        address creator,
        string calldata name,
        string calldata symbol,
        uint256 totalSupply,
        string calldata metadataUri
    ) external override onlyOwner {
        require(token != address(0), "Invalid token address");
        require(creator != address(0), "Invalid creator address");
        require(!_blacklistedCreators[creator], "Creator is blacklisted");
        require(_tokenInfo[token].token == address(0), "Token already registered");

        _tokenInfo[token] = TokenInfo({
            token: token,
            creator: creator,
            name: name,
            symbol: symbol,
            totalSupply: totalSupply,
            creationTime: block.timestamp,
            metadataUri: metadataUri,
            verified: false
        });

        _creatorTokens[creator].push(token);
        _allTokens.push(token);

        emit TokenRegistered(token, creator, name, symbol, totalSupply);
    }

    /// @notice Updates token verification status
    function setTokenVerification(address token, bool verified) external override onlyOwner {
        require(_tokenInfo[token].token != address(0), "Token not registered");
        
        _tokenInfo[token].verified = verified;
        
        if (verified) {
            _verifiedTokens.push(token);
        } else {
            _removeFromVerified(token);
        }

        emit TokenVerified(token, verified);
    }

    /// @notice Updates token metadata URI
    function updateTokenMetadata(address token, string calldata newUri) external override onlyOwner {
        require(_tokenInfo[token].token != address(0), "Token not registered");
        
        _tokenInfo[token].metadataUri = newUri;
        
        emit TokenMetadataUpdated(token, newUri);
    }

    /// @notice Blacklists a creator address
    function blacklistCreator(address creator, string calldata reason) external override onlyOwner {
        require(creator != address(0), "Invalid creator address");
        require(!_blacklistedCreators[creator], "Creator already blacklisted");

        _blacklistedCreators[creator] = true;
        
        emit CreatorBlacklisted(creator, reason);
    }

    /// @notice Gets information about a token
    function getTokenInfo(address token) external view override returns (TokenInfo memory) {
        require(_tokenInfo[token].token != address(0), "Token not registered");
        return _tokenInfo[token];
    }

    /// @notice Gets all tokens created by an address
    function getTokensByCreator(address creator) external view override returns (address[] memory) {
        return _creatorTokens[creator];
    }

    /// @notice Gets all verified tokens
    function getVerifiedTokens() external view override returns (address[] memory) {
        return _verifiedTokens;
    }

    /// @notice Checks if a creator is blacklisted
    function isCreatorBlacklisted(address creator) external view override returns (bool) {
        return _blacklistedCreators[creator];
    }

    /// @notice Gets the total number of registered tokens
    function getTotalTokens() external view override returns (uint256) {
        return _allTokens.length;
    }

    /// @notice Gets token addresses by page
    function getTokensByPage(uint256 page, uint256 pageSize) external view override returns (address[] memory) {
        require(pageSize > 0, "Invalid page size");
        
        uint256 start = page * pageSize;
        require(start < _allTokens.length, "Page out of bounds");
        
        uint256 end = start + pageSize;
        if (end > _allTokens.length) {
            end = _allTokens.length;
        }
        
        address[] memory tokens = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            tokens[i - start] = _allTokens[i];
        }
        
        return tokens;
    }

    /// @notice Internal function to remove a token from verified tokens array
    function _removeFromVerified(address token) internal {
        for (uint256 i = 0; i < _verifiedTokens.length; i++) {
            if (_verifiedTokens[i] == token) {
                if (i != _verifiedTokens.length - 1) {
                    _verifiedTokens[i] = _verifiedTokens[_verifiedTokens.length - 1];
                }
                _verifiedTokens.pop();
                break;
            }
        }
    }
} 