// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../registry/ContractRegistry.sol";
import "./IFalconVerifier.sol";

contract SecurityManager is AccessControl {
    bytes32 public constant SECURITY_ADMIN = keccak256("SECURITY_ADMIN");
    
    ContractRegistry public immutable registry;
    
    struct SecurityConfig {
        bool enabled;
        uint256 maxTransactionAmount;
        uint256 timeWindow;
        uint256 maxTransactionsPerWindow;
        uint256 lockDuration;
        uint256 minLiquidityPercentage;
        uint256 maxSellPercentage;
    }
    
    // Token => SecurityConfig
    mapping(address => SecurityConfig) public securityConfigs;
    // Token => User => Last Transaction Time
    mapping(address => mapping(address => uint256)) public lastTransactionTimes;
    // Token => User => Transactions in Window
    mapping(address => mapping(address => uint256)) public transactionsInWindow;
    
    // Events
    event SecurityConfigUpdated(address indexed token, SecurityConfig config);
    event TransactionValidated(address indexed token, address indexed user, bool success);
    
    constructor(address _registry) {
        require(_registry != address(0), "Invalid registry");
        registry = ContractRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SECURITY_ADMIN, msg.sender);
    }
    
    function updateSecurityConfig(
        address token,
        SecurityConfig calldata config
    ) external onlyRole(SECURITY_ADMIN) {
        securityConfigs[token] = config;
        emit SecurityConfigUpdated(token, config);
    }
    
    function validateTransaction(
        address token,
        address user,
        uint256 amount,
        bytes calldata signature
    ) external returns (bool) {
        SecurityConfig storage config = securityConfigs[token];
        require(config.enabled, "Security not enabled");
        
        // Check transaction amount
        if (amount > config.maxTransactionAmount) {
            return false;
        }
        
        // Check transaction frequency
        if (block.timestamp - lastTransactionTimes[token][user] <= config.timeWindow) {
            if (transactionsInWindow[token][user] >= config.maxTransactionsPerWindow) {
                return false;
            }
            transactionsInWindow[token][user]++;
        } else {
            lastTransactionTimes[token][user] = block.timestamp;
            transactionsInWindow[token][user] = 1;
        }
        
        // Verify Falcon signature
        address falconVerifier = registry.getContractAddress(keccak256("FALCON_VERIFIER"));
        if (!IFalconVerifier(falconVerifier).verifySignature(user, signature)) {
            return false;
        }
        
        bool success = true;
        emit TransactionValidated(token, user, success);
        return success;
    }
    
    function isSecurityEnabled(address token) external view returns (bool) {
        return securityConfigs[token].enabled;
    }
    
    function getSecurityConfig(
        address token
    ) external view returns (SecurityConfig memory) {
        return securityConfigs[token];
    }
    
    function getTransactionCount(
        address token,
        address user
    ) external view returns (uint256) {
        return transactionsInWindow[token][user];
    }
} 