// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/ITokenomics.sol";

/**
 * @title CEXLiquidityPool
 * @notice Manages CEX liquidity with cross-exchange balancing and dynamic allocation
 */
contract CEXLiquidityPool is Ownable, ReentrancyGuard, Pausable {
    // Structs
    struct Exchange {
        string name;
        address wallet;
        uint256 targetAllocation;  // in basis points
        uint256 currentBalance;
        uint256 lastRebalanceTime;
        uint256 volumeWeight;      // based on 24h volume
        bool isActive;
    }

    struct RebalanceConfig {
        uint256 threshold;         // minimum difference to trigger rebalance
        uint256 maxAmount;         // maximum amount per rebalance
        uint256 cooldown;          // minimum time between rebalances
        uint256 slippageTolerance; // maximum allowed slippage
    }

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_ALLOCATION = 500;  // 5%
    uint256 public constant MAX_ALLOCATION = 3000; // 30%
    uint256 public constant VOLUME_UPDATE_INTERVAL = 1 hours;
    uint256 public constant EMERGENCY_WITHDRAWAL_DELAY = 24 hours;

    // State variables
    mapping(address => Exchange) public exchanges;
    address[] public activeExchanges;
    RebalanceConfig public rebalanceConfig;
    uint256 public totalAllocated;
    uint256 public lastVolumeUpdate;
    uint256 public totalVolume;
    bool public autoRebalanceEnabled;

    address public immutable distributor;
    IERC20 public immutable rewardToken;

    // Events
    event ExchangeAdded(string name, address indexed wallet);
    event ExchangeRemoved(address indexed wallet);
    event AllocationUpdated(address indexed exchange, uint256 newAllocation);
    event VolumeUpdated(address indexed exchange, uint256 volume);
    event Rebalanced(address indexed from, address indexed to, uint256 amount);
    event ConfigUpdated(
        uint256 threshold,
        uint256 maxAmount,
        uint256 cooldown,
        uint256 slippageTolerance
    );
    event AutoRebalanceToggled(bool enabled);
    event EmergencyWithdrawn(address indexed token, uint256 amount, address recipient);

    // Modifiers
    modifier onlyDistributor() {
        require(msg.sender == distributor, "Only distributor");
        _;
    }

    modifier exchangeExists(address wallet) {
        require(exchanges[wallet].isActive, "Exchange not found");
        _;
    }

    constructor(
        address _distributor,
        address _rewardToken
    ) Ownable(msg.sender) {
        require(_distributor != address(0), "Invalid distributor");
        require(_rewardToken != address(0), "Invalid reward token");
        distributor = _distributor;
        rewardToken = IERC20(_rewardToken);
        
        // Initialize default rebalance config
        rebalanceConfig = RebalanceConfig({
            threshold: 500,        // 5%
            maxAmount: 10000 ether,
            cooldown: 6 hours,
            slippageTolerance: 100 // 1%
        });
        
        autoRebalanceEnabled = true;
    }

    /**
     * @notice Adds a new exchange
     */
    function addExchange(
        string calldata name,
        address wallet,
        uint256 targetAllocation
    ) external onlyOwner {
        require(wallet != address(0), "Invalid wallet");
        require(bytes(name).length > 0, "Empty name");
        require(!exchanges[wallet].isActive, "Exchange exists");
        require(
            targetAllocation >= MIN_ALLOCATION &&
            targetAllocation <= MAX_ALLOCATION,
            "Invalid allocation"
        );
        require(totalAllocated + targetAllocation <= BASIS_POINTS, "Exceeds 100%");

        exchanges[wallet] = Exchange({
            name: name,
            wallet: wallet,
            targetAllocation: targetAllocation,
            currentBalance: 0,
            lastRebalanceTime: 0,
            volumeWeight: 0,
            isActive: true
        });

        activeExchanges.push(wallet);
        totalAllocated += targetAllocation;

        emit ExchangeAdded(name, wallet);
    }

    /**
     * @notice Removes an exchange
     */
    function removeExchange(address wallet) external onlyOwner exchangeExists(wallet) {
        Exchange storage exchange = exchanges[wallet];
        require(exchange.currentBalance == 0, "Balance not zero");

        totalAllocated -= exchange.targetAllocation;
        exchange.isActive = false;

        // Remove from active exchanges array
        for (uint256 i = 0; i < activeExchanges.length; i++) {
            if (activeExchanges[i] == wallet) {
                activeExchanges[i] = activeExchanges[activeExchanges.length - 1];
                activeExchanges.pop();
                break;
            }
        }

        emit ExchangeRemoved(wallet);
    }

    /**
     * @notice Updates exchange allocation
     */
    function updateAllocation(
        address wallet,
        uint256 newAllocation
    ) external onlyOwner exchangeExists(wallet) {
        require(
            newAllocation >= MIN_ALLOCATION &&
            newAllocation <= MAX_ALLOCATION,
            "Invalid allocation"
        );

        Exchange storage exchange = exchanges[wallet];
        totalAllocated = totalAllocated - exchange.targetAllocation + newAllocation;
        require(totalAllocated <= BASIS_POINTS, "Exceeds 100%");

        exchange.targetAllocation = newAllocation;
        emit AllocationUpdated(wallet, newAllocation);
    }

    /**
     * @notice Updates exchange volume data
     */
    function updateVolume(
        address wallet,
        uint256 volume
    ) external onlyOwner exchangeExists(wallet) {
        require(
            block.timestamp >= lastVolumeUpdate + VOLUME_UPDATE_INTERVAL,
            "Too frequent"
        );

        Exchange storage exchange = exchanges[wallet];
        totalVolume = totalVolume - exchange.volumeWeight + volume;
        exchange.volumeWeight = volume;
        lastVolumeUpdate = block.timestamp;

        emit VolumeUpdated(wallet, volume);
    }

    /**
     * @notice Rebalances liquidity between exchanges
     */
    function rebalance(
        address from,
        address to,
        uint256 amount
    ) external onlyOwner exchangeExists(from) exchangeExists(to) {
        require(amount > 0, "Zero amount");
        require(amount <= rebalanceConfig.maxAmount, "Exceeds max amount");
        require(
            block.timestamp >= exchanges[from].lastRebalanceTime + rebalanceConfig.cooldown,
            "Cooldown active"
        );

        // Transfer tokens between exchanges
        require(rewardToken.transfer(to, amount), "Transfer failed");
        
        exchanges[from].currentBalance -= amount;
        exchanges[to].currentBalance += amount;
        exchanges[from].lastRebalanceTime = block.timestamp;

        emit Rebalanced(from, to, amount);
    }

    /**
     * @notice Auto-rebalances based on volume weights
     */
    function autoRebalance() external nonReentrant whenNotPaused {
        require(autoRebalanceEnabled, "Auto-rebalance disabled");
        require(activeExchanges.length >= 2, "Insufficient exchanges");
        require(totalVolume > 0, "No volume data");

        for (uint256 i = 0; i < activeExchanges.length; i++) {
            address wallet = activeExchanges[i];
            Exchange storage exchange = exchanges[wallet];
            
            uint256 targetBalance = (totalVolume * exchange.targetAllocation) / BASIS_POINTS;
            uint256 diff = targetBalance > exchange.currentBalance ?
                targetBalance - exchange.currentBalance :
                exchange.currentBalance - targetBalance;

            if (diff >= rebalanceConfig.threshold) {
                // Find exchange to rebalance with
                address bestMatch = _findRebalanceMatch(wallet, targetBalance > exchange.currentBalance);
                if (bestMatch != address(0)) {
                    uint256 amount = diff > rebalanceConfig.maxAmount ?
                        rebalanceConfig.maxAmount : diff;
                    if (targetBalance > exchange.currentBalance) {
                        this.rebalance(bestMatch, wallet, amount);
                    } else {
                        this.rebalance(wallet, bestMatch, amount);
                    }
                }
            }
        }
    }

    /**
     * @notice Updates rebalance configuration
     */
    function updateConfig(
        uint256 threshold,
        uint256 maxAmount,
        uint256 cooldown,
        uint256 slippageTolerance
    ) external onlyOwner {
        require(threshold > 0 && threshold <= 2000, "Invalid threshold"); // max 20%
        require(slippageTolerance <= 500, "Invalid slippage"); // max 5%

        rebalanceConfig = RebalanceConfig({
            threshold: threshold,
            maxAmount: maxAmount,
            cooldown: cooldown,
            slippageTolerance: slippageTolerance
        });

        emit ConfigUpdated(threshold, maxAmount, cooldown, slippageTolerance);
    }

    /**
     * @notice Toggles auto-rebalancing
     */
    function toggleAutoRebalance() external onlyOwner {
        autoRebalanceEnabled = !autoRebalanceEnabled;
        emit AutoRebalanceToggled(autoRebalanceEnabled);
    }

    /**
     * @notice Finds best exchange for rebalancing
     */
    function _findRebalanceMatch(
        address source,
        bool isBuying
    ) internal view returns (address) {
        address bestMatch = address(0);
        uint256 bestDiff = type(uint256).max;

        for (uint256 i = 0; i < activeExchanges.length; i++) {
            address wallet = activeExchanges[i];
            if (wallet == source) continue;

            Exchange storage exchange = exchanges[wallet];
            if (block.timestamp < exchange.lastRebalanceTime + rebalanceConfig.cooldown) continue;

            uint256 targetBalance = (totalVolume * exchange.targetAllocation) / BASIS_POINTS;
            uint256 currentDiff = isBuying ?
                exchange.currentBalance - targetBalance :
                targetBalance - exchange.currentBalance;

            if (currentDiff > rebalanceConfig.threshold && currentDiff < bestDiff) {
                bestMatch = wallet;
                bestDiff = currentDiff;
            }
        }

        return bestMatch;
    }

    /**
     * @notice Distributes new funds from the automated distributor
     */
    function distributeRewards() external payable onlyDistributor nonReentrant whenNotPaused {
        require(msg.value > 0, "Zero value");
        
        // Distribute based on volume weights
        for (uint256 i = 0; i < activeExchanges.length; i++) {
            address wallet = activeExchanges[i];
            Exchange storage exchange = exchanges[wallet];
            
            if (exchange.volumeWeight > 0) {
                uint256 amount = (msg.value * exchange.volumeWeight) / totalVolume;
                exchange.currentBalance += amount;
                require(rewardToken.transfer(wallet, amount), "Transfer failed");
            }
        }
    }

    /**
     * @notice Emergency withdrawal of stuck funds
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        
        if (token == address(0)) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            require(IERC20(token).transfer(recipient, amount), "Token transfer failed");
        }

        emit EmergencyWithdrawn(token, amount, recipient);
    }

    /**
     * @notice Pauses all non-essential functions
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses all functions
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {
        require(msg.sender == distributor, "Only distributor");
    }
} 