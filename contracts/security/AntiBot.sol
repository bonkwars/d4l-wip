// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract AntiBot is Ownable, ReentrancyGuard, Pausable {
    // Constants
    uint256 public constant MAX_TX_COUNT = 5;      // Max transactions per block
    uint256 public constant MIN_HOLD_TIME = 1 minutes;
    uint256 public constant MAX_GAS_PRICE = 500 gwei;
    
    // Structs
    struct ValidationParams {
        bool allowed;      // Changed from isWhitelisted
        uint256 amount;
        bool isBuy;
    }

    struct BotProtection {
        uint256 firstTxTime;          // First transaction timestamp
        uint256 txCount;              // Transactions in current block
        uint256 lastBlockNumber;      // Last transaction block number
        bool whitelisted;             // Changed from isWhitelisted
    }

    // State variables
    mapping(address => BotProtection) public protection;
    mapping(address => bool) public protectedTokens;
    uint256 public launchBlock;
    bool public tradingEnabled;
    
    // Events
    event TokenProtectionEnabled(address indexed token);
    event TokenProtectionDisabled(address indexed token);
    event AddressWhitelisted(address indexed account, bool status);
    event TradingEnabled();
    event BotDetected(address indexed bot, string reason);

    constructor() Ownable(msg.sender) {
        launchBlock = block.number;
    }

    function validateTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) external view returns (bool) {
        if (!protectedTokens[token]) return true;
        if (!tradingEnabled) return false;
        
        // Skip checks for whitelisted addresses
        if (protection[from].whitelisted || protection[to].whitelisted) {
            return true;
        }

        // Check gas price
        if (tx.gasprice > MAX_GAS_PRICE) {
            return false;
        }

        // Check if it's the first transaction for the sender
        if (protection[from].firstTxTime == 0) {
            return true; // Allow first transaction
        }

        // Check minimum hold time
        if (block.timestamp - protection[from].firstTxTime < MIN_HOLD_TIME) {
            return false;
        }

        // Check transaction count in current block
        if (block.number == protection[from].lastBlockNumber) {
            if (protection[from].txCount >= MAX_TX_COUNT) {
                return false;
            }
        }

        return true;
    }

    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled();
    }

    function setProtectedToken(address token, bool protected) external onlyOwner {
        protectedTokens[token] = protected;
        if (protected) {
            emit TokenProtectionEnabled(token);
        } else {
            emit TokenProtectionDisabled(token);
        }
    }

    function whitelistAddress(address account, bool status) external onlyOwner {
        protection[account].whitelisted = status;
        emit AddressWhitelisted(account, status);
    }

    function validateTransaction(
        address account,
        address token
    ) external nonReentrant whenNotPaused returns (bool) {
        if (!tradingEnabled) {
            revert("Trading not enabled");
        }

        if (!protectedTokens[token]) {
            return true;
        }

        BotProtection storage userProtection = protection[account];
        
        // Whitelist check
        if (userProtection.whitelisted) {
            return true;
        }

        // Gas price check
        if (tx.gasprice > MAX_GAS_PRICE) {
            emit BotDetected(account, "High gas price");
            return false;
        }

        // First transaction check
        if (userProtection.firstTxTime == 0) {
            userProtection.firstTxTime = block.timestamp;
        } else if (block.timestamp - userProtection.firstTxTime < MIN_HOLD_TIME) {
            emit BotDetected(account, "Minimum hold time not met");
            return false;
        }

        // Block transaction count check
        if (block.number == userProtection.lastBlockNumber) {
            userProtection.txCount++;
            if (userProtection.txCount > MAX_TX_COUNT) {
                emit BotDetected(account, "Too many transactions per block");
                return false;
            }
        } else {
            userProtection.txCount = 1;
            userProtection.lastBlockNumber = block.number;
        }

        // Sniper check
        if (block.number - launchBlock < 5) {
            emit BotDetected(account, "Sniping attempt");
            return false;
        }

        return true;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // View functions
    function isWhitelisted(address account) external view returns (bool) {
        return protection[account].whitelisted;
    }

    function getProtection(address account) external view returns (
        uint256 firstTxTime,
        uint256 txCount,
        uint256 lastBlockNumber,
        bool whitelistStatus
    ) {
        BotProtection memory p = protection[account];
        return (p.firstTxTime, p.txCount, p.lastBlockNumber, p.whitelisted);
    }

    function lastTradeBlock(address account) external view returns (uint256) {
        return protection[account].lastBlockNumber;
    }
}
