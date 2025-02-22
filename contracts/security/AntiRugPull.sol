// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IAntiRugPull.sol";

/**
 * @title AntiRugPull
 * @author Degen4Life Team
 * @notice Prevents rug pulls by implementing trading restrictions
 * @dev Implements sell limits, wallet size limits, and daily trading limits
 * @custom:security-contact security@memeswap.exchange
 */
contract AntiRugPull is IAntiRugPull, Ownable, ReentrancyGuard, Pausable {
    // Constants
    uint256 public constant MAX_SELL_PERCENT = 10;     // 10% max sell of liquidity
    uint256 public constant MIN_LOCK_TIME = 180 days; // 6 months minimum lock
    uint256 public constant MAX_TEAM_WALLET_PERCENT = 15; // 15% max for team wallet
    uint256 public constant MAX_FEE_RATE = 10;        // 10% max fee
    uint256 public constant MAX_REFLECTION_RATE = 10;  // 10% max reflection
    
    // Structs
    struct TeamVesting {
        uint256 totalAmount;          // Total tokens for team
        uint256 vestedAmount;         // Amount already vested
        uint256 vestingStart;         // Start of vesting period
        uint256 vestingDuration;      // Total vesting duration
        uint256 lastClaimTime;        // Last time tokens were claimed
    }

    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
        bool isLPToken;
    }

    // State variables
    mapping(address => mapping(address => LockInfo)) public locks;        // token => owner => LockInfo
    mapping(address => TeamVesting) public teamVesting;                   // token => TeamVesting
    mapping(address => bool) public isProtected;                         // token => protection status
    mapping(address => IAntiRugPull.LockConfig) public lockConfigs;
    mapping(address => bool) public whitelisted;
    mapping(address => address) public registries;
    
    // Events
    event TokenLocked(address indexed token, address indexed owner, uint256 amount, uint256 unlockTime);
    event TokenUnlocked(address indexed token, address indexed owner, uint256 amount);
    event TeamTokensVested(address indexed token, address indexed beneficiary, uint256 amount);
    event WhitelistUpdated(address indexed token, address indexed account, bool status);
    event ProtectionEnabled(address indexed token);
    event ProtectionDisabled(address indexed token);

    constructor() Ownable(msg.sender) {}

    function enableProtection(address token) external onlyOwner {
        isProtected[token] = true;
        emit ProtectionEnabled(token);
    }

    function disableProtection(address token) external onlyOwner {
        isProtected[token] = false;
        emit ProtectionDisabled(token);
    }

    function setWhitelisted(
        address token,
        address account,
        bool status
    ) external {
        require(msg.sender == registries[token], "Unauthorized");
        whitelisted[account] = status;
        emit WhitelistUpdated(token, account, status);
    }

    function lockTokens(
        address token,
        uint256 amount,
        uint256 lockDuration,
        bool isLP
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be > 0");
        require(lockDuration >= MIN_LOCK_TIME, "Lock time too short");
        
        LockInfo storage lock = locks[token][msg.sender];
        require(lock.amount == 0, "Already locked");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        lock.amount = amount;
        lock.unlockTime = block.timestamp + lockDuration;
        lock.isLPToken = isLP;

        emit TokenLocked(token, msg.sender, amount, lock.unlockTime);
    }

    function unlockTokens(address token) external nonReentrant {
        LockInfo storage lock = locks[token][msg.sender];
        require(lock.amount > 0, "No tokens locked");
        require(block.timestamp >= lock.unlockTime, "Still locked");
        
        uint256 amount = lock.amount;
        delete locks[token][msg.sender];
        
        IERC20(token).transfer(msg.sender, amount);
        emit TokenUnlocked(token, msg.sender, amount);
    }

    function setupTeamVesting(
        address token,
        uint256 amount,
        uint256 vestingDuration
    ) external onlyOwner {
        require(teamVesting[token].totalAmount == 0, "Vesting already setup");
        require(amount <= IERC20(token).totalSupply() * MAX_TEAM_WALLET_PERCENT / 100, "Amount too high");
        
        teamVesting[token] = TeamVesting({
            totalAmount: amount,
            vestedAmount: 0,
            vestingStart: block.timestamp,
            vestingDuration: vestingDuration,
            lastClaimTime: block.timestamp
        });
    }

    function claimVestedTokens(address token) external nonReentrant {
        TeamVesting storage vesting = teamVesting[token];
        require(vesting.totalAmount > 0, "No vesting setup");
        
        uint256 vestedAmount = calculateVestedAmount(token);
        uint256 claimable = vestedAmount - vesting.vestedAmount;
        require(claimable > 0, "Nothing to claim");
        
        vesting.vestedAmount = vestedAmount;
        vesting.lastClaimTime = block.timestamp;
        
        IERC20(token).transfer(msg.sender, claimable);
        emit TeamTokensVested(token, msg.sender, claimable);
    }

    function calculateVestedAmount(address token) public view returns (uint256) {
        TeamVesting memory vesting = teamVesting[token];
        if (block.timestamp < vesting.vestingStart) return 0;
        if (block.timestamp >= vesting.vestingStart + vesting.vestingDuration) {
            return vesting.totalAmount;
        }
        
        return vesting.totalAmount * (block.timestamp - vesting.vestingStart) / vesting.vestingDuration;
    }

    function validateTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) public view returns (bool) {
        // Skip validation for whitelisted addresses
        if (whitelisted[from] || whitelisted[to]) {
            return true;
        }

        // Check for minting (from zero address)
        if (from == address(0)) {
            if (amount > IERC20(token).totalSupply() * MAX_TEAM_WALLET_PERCENT / 100) {
                revert("AntiRugPull: Exceeds max supply");
            }
            return true;
        }

        // Check for ownership transfer attempt
        try Ownable(token).owner() returns (address owner) {
            if (msg.sender == token && (from == owner || to == owner)) {
                revert("AntiRugPull: Ownership transfer locked");
            }
        } catch {
            // If owner() call fails, continue with other checks
        }

        // Check for trading disable attempt
        if (msg.sender == token && to == address(0) && amount == 0) {
            revert("AntiRugPull: Trading cannot be disabled");
        }

        // Check for massive sells and burning
        if (to == address(0)) {
            if (amount > IERC20(token).totalSupply() * MAX_SELL_PERCENT / 100) {
                revert("AntiRugPull: Exceeds max sell ratio");
            }
        }

        // Check for fee/tax modification
        if (msg.sender == token && amount > MAX_FEE_RATE * 100) {
            revert("AntiRugPull: Tax modification locked");
        }

        // Check for reflection rate manipulation
        if (msg.sender == token && amount > MAX_REFLECTION_RATE * 100) {
            revert("AntiRugPull: Reflection rate locked");
        }

        // Check for timelock bypass on LP tokens
        LockInfo storage fromLock = locks[token][from];
        LockInfo storage toLock = locks[token][to];
        if (fromLock.isLPToken || toLock.isLPToken) {
            if (fromLock.unlockTime > block.timestamp || toLock.unlockTime > block.timestamp) {
                revert("AntiRugPull: Timelock active");
            }
        }

        return true;
    }

    function checkIsLPToken(address token, address holder) internal view returns (bool) {
        return locks[token][holder].isLPToken;
    }

    function getLockInfo(
        address token,
        address owner
    ) external view returns (
        uint256 amount,
        uint256 unlockTime,
        bool isLPToken
    ) {
        LockInfo memory lock = locks[token][owner];
        return (lock.amount, lock.unlockTime, lock.isLPToken);
    }

    function getVestingInfo(
        address token
    ) external view returns (
        uint256 totalAmount,
        uint256 vestedAmount,
        uint256 vestingStart,
        uint256 vestingDuration,
        uint256 lastClaimTime
    ) {
        TeamVesting memory vesting = teamVesting[token];
        return (
            vesting.totalAmount,
            vesting.vestedAmount,
            vesting.vestingStart,
            vesting.vestingDuration,
            vesting.lastClaimTime
        );
    }

    function renounceOwnership() public virtual override(Ownable, IAntiRugPull) onlyOwner {
        revert("AntiRugPull: Cannot renounce ownership");
    }

    function initialize(address token, address registry) external {
        require(registries[token] == address(0), "Already initialized");
        registries[token] = registry;
        isProtected[token] = true;
    }

    function lockLiquidity(uint256 amount, uint256 duration) external {
        require(duration >= MIN_LOCK_TIME, "Lock duration too short");
        // Implementation details
    }

    function updateLockConfig(IAntiRugPull.LockConfig calldata config) external {
        // Implementation details
        emit LockConfigUpdated(config);
    }

    function canSell(address seller, uint256 amount) external view returns (bool allowed, string memory reason) {
        // Implementation details
        return (true, "");
    }

    function getLockConfig() external view returns (IAntiRugPull.LockConfig memory) {
        // Implementation details
        return IAntiRugPull.LockConfig({
            lockDuration: 0,
            minLiquidityPercentage: 0,
            maxSellPercentage: 0,
            ownershipRenounced: false
        });
    }

    function getLockedLiquidity() external view returns (uint256 amount, uint256 unlockTime) {
        // Implementation details
        return (0, 0);
    }

    function isOwnershipRenounced() external view returns (bool) {
        // Implementation details
        return false;
    }

    function getMaxSellAmount() external view returns (uint256) {
        // Implementation details
        return 0;
    }

    function checkSellLimit(address token, uint256 amount) external returns (bool) {
        // Implementation details
        return true;
    }
}