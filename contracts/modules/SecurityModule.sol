// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseModule.sol";
import "../interfaces/IAntiBot.sol";
import "../interfaces/IAntiRugPull.sol";

contract SecurityModule is BaseModule {
    bytes32 private constant SECURITY_ADMIN = keccak256("SECURITY_ADMIN");
    
    struct SecurityConfig {
        uint256 maxTransactionAmount;
        uint256 timeWindow;
        uint256 maxTransactionsPerWindow;
        uint256 lockDuration;
        uint256 minLiquidityPercentage;
        uint256 maxSellPercentage;
    }
    
    event SecurityConfigUpdated(bytes32 indexed tokenType, SecurityConfig config);
    event TradingValidated(address indexed trader, address indexed token, bool success);
    
    function initialize(address token, address _registry) external initializer {
        __BaseModule_init(_registry);
        _grantRole(SECURITY_ADMIN, msg.sender);
    }
    
    function updateSecurityConfig(
        bytes32 tokenType,
        SecurityConfig calldata config
    ) external onlyRole(SECURITY_ADMIN) {
        address antiBot = getContractAddress(registry.ANTI_BOT());
        address antiRugPull = getContractAddress(registry.ANTI_RUGPULL());
        
        // Update AntiBot configuration
        IAntiBot(antiBot).updateProtectionConfig(
            config.maxTransactionAmount,
            config.timeWindow,
            config.maxTransactionsPerWindow
        );
        
        // Update AntiRugPull configuration
        IAntiRugPull.LockConfig memory lockConfig = IAntiRugPull.LockConfig({
            lockDuration: config.lockDuration,
            minLiquidityPercentage: config.minLiquidityPercentage,
            maxSellPercentage: config.maxSellPercentage,
            ownershipRenounced: false
        });
        
        IAntiRugPull(antiRugPull).updateLockConfig(lockConfig);
        
        emit SecurityConfigUpdated(tokenType, config);
    }
    
    function validateTrading(
        address token,
        address trader,
        uint256 amount,
        bool isBuy
    ) external view whenNotPaused returns (bool) {
        address antiBot = getContractAddress(registry.ANTI_BOT());
        address antiRugPull = getContractAddress(registry.ANTI_RUGPULL());
        
        // Validate against bot detection
        bool botCheck = IAntiBot(antiBot).validateTrade(
            trader,
            amount,
            isBuy
        );
        
        // Validate against rugpull protection
        bool rugPullCheck = true;
        if (!isBuy) {
            (bool allowed,) = IAntiRugPull(antiRugPull).canSell(trader, amount);
            rugPullCheck = allowed;
        }
        
        return botCheck && rugPullCheck;
    }
    
    function whitelistAddress(
        address token,
        address account,
        bool status
    ) external onlyRole(SECURITY_ADMIN) {
        address antiBot = getContractAddress(registry.ANTI_BOT());
        address antiRugPull = getContractAddress(registry.ANTI_RUGPULL());
        
        IAntiBot(antiBot).whitelistAddress(token, status);
        IAntiRugPull(antiRugPull).setWhitelisted(token, account, status);
    }
} 