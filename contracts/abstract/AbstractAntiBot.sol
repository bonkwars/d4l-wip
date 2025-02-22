// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IAntiBot.sol";

abstract contract AbstractAntiBot is Ownable, IAntiBot {
    // Pack structs for gas optimization
    struct TransactionData {
        uint96 totalTransactions;    // 12 bytes
        uint96 transactionsInWindow; // 12 bytes
        uint32 lastTransactionTime;  // 4 bytes
        uint32 lastAmount;           // 4 bytes
    }

    // Pack configuration into single slot
    struct BotConfig {
        uint96 maxAmount;           // 12 bytes
        uint32 timeWindow;          // 4 bytes
        uint32 maxTxPerWindow;      // 4 bytes
        bool paused;                // 1 byte
        uint8 reserved;             // 1 byte padding
    }

    // Custom errors for gas savings
    error ExceedsMaxAmount();
    error TooManyTransactions();
    error Unauthorized();
    error InvalidConfig();
    error ContractBlacklisted();

    // Constants
    uint256 private constant MAX_BLACKLIST_REASON_LENGTH = 100;
    uint256 private constant MIN_TIME_WINDOW = 1 minutes;
    uint256 private constant MAX_TIME_WINDOW = 1 days;
    uint256 private constant MAX_TRANSACTIONS_PER_WINDOW = 1000;
    uint256 private constant MIN_TRANSACTION_AMOUNT = 1000;

    // Storage
    mapping(address => TransactionData) private _transactionData;
    mapping(address => bool) private _blacklistedAddresses;
    mapping(address => bool) private _whitelistedContracts;
    BotConfig private _config;

    // Events with indexed params
    event BotDetected(address indexed bot, string reason, uint256 timestamp);
    event ConfigUpdated(uint96 maxAmount, uint32 timeWindow, uint32 maxTxPerWindow);
    event AddressBlacklisted(address indexed account, string reason);
    event AddressWhitelisted(address indexed account);
    event AddressUnblacklisted(address indexed account);
    event BlacklistAuthorityUpdated(address indexed authority);

    // Add authority control
    address public blacklistAuthority;

    // Add missing modifier
    modifier onlyBlacklistAuthority() {
        if (msg.sender != blacklistAuthority && 
            !(msg.sender == owner() && blacklistAuthority == address(0))) {
            revert Unauthorized();
        }
        _;
    }

    constructor() {
        _config = BotConfig({
            maxAmount: 1000e18,
            timeWindow: 1 hours,
            maxTxPerWindow: 10,
            paused: false,
            reserved: 0
        });
    }

    mapping(address => bool) public whitelisted;
    mapping(address => uint256[]) public transactionHistory;
    uint256 public maxTransactionAmount;
    uint256 public timeWindow;
    uint256 public maxTransactionsPerWindow;

    function validateTrade(
        address trader,
        uint256 amount,
        bool isBuy
    ) external view virtual override returns (bool) {
        if (whitelisted[trader]) {
            return true;
        }

        if (amount > maxTransactionAmount) {
            return false;
        }

        uint256 currentTime = block.timestamp;
        uint256 windowStart = currentTime - timeWindow;
        uint256 txCount = 0;

        // Count transactions in current window
        for (uint256 i = 0; i < transactionHistory[trader].length; i++) {
            if (transactionHistory[trader][i] > windowStart) {
                txCount++;
            }
        }

        return txCount < maxTransactionsPerWindow;
    }

    function updateConfig(
        uint96 maxAmount,
        uint32 timeWindow,
        uint32 maxTxPerWindow
    ) external onlyOwner {
        if (timeWindow < MIN_TIME_WINDOW || timeWindow > MAX_TIME_WINDOW) {
            revert InvalidConfig();
        }

        _config = BotConfig({
            maxAmount: maxAmount,
            timeWindow: timeWindow,
            maxTxPerWindow: maxTxPerWindow,
            paused: _config.paused,
            reserved: 0
        });

        emit ConfigUpdated(maxAmount, timeWindow, maxTxPerWindow);
    }

    // View functions
    function getTransactionStats(
        address account
    ) external view returns (
        uint256 total,
        uint256 inWindow,
        uint256 lastTime
    ) {
        TransactionData storage data = _transactionData[account];
        return (
            data.totalTransactions,
            data.transactionsInWindow,
            data.lastTransactionTime
        );
    }

    /// @notice Checks if an address is potentially a bot
    function isBot(address account, uint256 amount) public view override returns (bool) {
        // Add contract check
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        // Check if it's a contract, but allow known good contracts
        if (size > 0 && !_whitelistedContracts[account]) {
            return true;
        }

        if (_blacklistedAddresses[account]) {
            return true;
        }

        TransactionData memory data = _transactionData[account];
        
        // Check transaction amount
        if (amount > _config.maxAmount) {
            return true;
        }

        // Check transaction frequency
        if (block.timestamp - data.lastTransactionTime <= _config.timeWindow) {
            if (data.transactionsInWindow >= _config.maxTxPerWindow) {
                return true;
            }
        }

        // Check for repetitive patterns
        if (data.lastAmount == amount && data.transactionsInWindow > _config.maxTxPerWindow / 2) {
            return true;
        }

        return false;
    }

    /// @notice Updates the protection configuration
    function updateProtectionConfig(
        uint256 maxAmount,
        uint256 newTimeWindow,
        uint256 maxTxPerWindow
    ) external override onlyOwner {
        require(maxAmount >= MIN_TRANSACTION_AMOUNT, "Amount too small");
        require(newTimeWindow >= MIN_TIME_WINDOW && newTimeWindow <= MAX_TIME_WINDOW, "Invalid time window");
        require(maxTxPerWindow > 0 && maxTxPerWindow <= MAX_TRANSACTIONS_PER_WINDOW, "Invalid max transactions");

        _config = BotConfig({
            maxAmount: uint96(maxAmount),
            timeWindow: uint32(newTimeWindow),
            maxTxPerWindow: uint32(maxTxPerWindow),
            paused: _config.paused,
            reserved: 0
        });

        emit ConfigUpdated(
            uint96(maxAmount),
            uint32(newTimeWindow),
            uint32(maxTxPerWindow)
        );
    }

    /// @notice Records a transaction for bot detection
    function recordTransaction(address from, address to, uint256 amount) external override {
        TransactionData storage data = _transactionData[from];
        
        // Reset window if expired
        if (block.timestamp - data.lastTransactionTime > _config.timeWindow) {
            data.transactionsInWindow = 0;
        }

        // Update transaction data
        data.totalTransactions++;
        data.transactionsInWindow++;
        data.lastTransactionTime = uint32(block.timestamp);
        data.lastAmount = uint32(amount);

        // Check for bot patterns and emit event if detected
        if (isBot(from, amount)) {
            emit BotDetected(from, "Suspicious transaction pattern detected", block.timestamp);
            _blacklistedAddresses[from] = true;
        }
    }

    /// @notice Gets the current protection configuration
    function getProtectionConfig() external view override returns (
        uint256 maxAmount,
        uint256 window,
        uint256 maxTxPerWindow
    ) {
        return (_config.maxAmount, _config.timeWindow, _config.maxTxPerWindow);
    }

    /// @notice Internal function to blacklist an address
    function _blacklistAddress(address account) internal {
        _blacklistedAddresses[account] = true;
        emit BotDetected(account, "Address blacklisted", block.timestamp);
    }

    // Add whitelist for legitimate contracts (e.g., known DEX routers)
    function whitelistContract(address contractAddress) external onlyOwner {
        _whitelistedContracts[contractAddress] = true;
        emit AddressWhitelisted(contractAddress);
    }

    // Add validation for contract interactions
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function _isValidInteraction(address account) internal view returns (bool) {
        // Allow known contracts (e.g., routers)
        if (_whitelistedContracts[account]) {
            return true;
        }
        
        // Block unknown contracts
        if (_isContract(account) && !_whitelistedContracts[account]) {
            return false;
        }

        return true;
    }

    // Fix setBlacklistAuthority implementation
    function setBlacklistAuthority(address _authority) external onlyOwner {
        if (_authority == address(0)) revert InvalidConfig();
        blacklistAuthority = _authority;
        emit BlacklistAuthorityUpdated(_authority);
    }

    // Fix revokeBlacklistAuthority implementation
    function revokeBlacklistAuthority() external onlyOwner {
        address oldAuthority = blacklistAuthority;
        blacklistAuthority = address(0);
        emit BlacklistAuthorityUpdated(address(0));
    }

    // Fix unblacklistAddress event
    function unblacklistAddress(address account) external onlyBlacklistAuthority {
        if (!_blacklistedAddresses[account]) revert InvalidConfig();
        _blacklistedAddresses[account] = false;
        emit AddressUnblacklisted(account);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklistedAddresses[account];
    }
} 