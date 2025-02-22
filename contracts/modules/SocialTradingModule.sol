// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseModule.sol";
import "../interfaces/ISocialTrading.sol";
import "../interfaces/IContractRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title SocialTradingModule
 * @notice Implements social trading functionality including copy trading and trader reputation
 * @dev Inherits from BaseModule and implements ISocialTrading
 */
contract SocialTradingModule is BaseModule, ISocialTrading {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // Storage
    mapping(address => Trader) private _traders;
    mapping(bytes32 => Strategy) private _strategies;
    mapping(address => mapping(address => CopyTrading)) private copyTrades;
    mapping(address => EnumerableSet.AddressSet) private following;
    mapping(address => EnumerableSet.AddressSet) private followers;
    mapping(address => EnumerableSet.Bytes32Set) private traderStrategies;

    // Constants
    uint256 private constant MAX_PERFORMANCE_FEE = 3000; // 30% max performance fee
    uint256 private constant MIN_REPUTATION_SCORE = 100;
    uint256 private constant REPUTATION_MULTIPLIER = 100;
    uint256 private constant MAX_ACTIVE_STRATEGIES = 5;

    // Events (in addition to interface events)
    event PerformanceFeePaid(
        address indexed trader,
        address indexed follower,
        uint256 amount
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(address _registry) external initializer {
        __BaseModule_init(_registry);
    }

    /**
     * @notice Registers a new trader
     * @param profileURI IPFS URI containing trader profile info
     */
    function registerTrader(string calldata profileURI) external override {
        require(bytes(profileURI).length > 0, "Invalid profile URI");
        require(!_traders[msg.sender].isActive, "Already registered");

        _traders[msg.sender] = Trader({
            reputation: MIN_REPUTATION_SCORE,
            successfulTrades: 0,
            totalTrades: 0,
            totalVolume: 0,
            followers: 0,
            isActive: true,
            profileURI: profileURI
        });

        emit TraderRegistered(msg.sender, profileURI);
    }

    /**
     * @notice Creates a new trading strategy
     * @param name Strategy name
     * @param description Strategy description
     * @param minAmount Minimum copy amount
     * @param maxAmount Maximum copy amount
     * @param performanceFee Performance fee in basis points
     */
    function createStrategy(
        string calldata name,
        string calldata description,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 performanceFee
    ) external override returns (bytes32) {
        require(_traders[msg.sender].isActive, "Not a registered trader");
        require(bytes(name).length > 0, "Invalid name");
        require(minAmount > 0, "Invalid min amount");
        require(maxAmount >= minAmount, "Invalid max amount");
        require(performanceFee <= MAX_PERFORMANCE_FEE, "Fee too high");
        require(
            traderStrategies[msg.sender].length() < MAX_ACTIVE_STRATEGIES,
            "Too many strategies"
        );

        bytes32 strategyId = keccak256(
            abi.encodePacked(msg.sender, name, block.timestamp)
        );

        Strategy storage strategy = _strategies[strategyId];
        strategy.trader = msg.sender;
        strategy.name = name;
        strategy.description = description;
        strategy.minAmount = minAmount;
        strategy.maxAmount = maxAmount;
        strategy.performanceFee = performanceFee;
        strategy.isActive = true;

        traderStrategies[msg.sender].add(strategyId);

        emit StrategyCreated(strategyId, msg.sender, name);
        return strategyId;
    }

    /**
     * @notice Starts copy trading a trader
     * @param trader Address of trader to copy
     * @param amount Amount to allocate for copy trading
     */
    function startCopyTrading(
        address trader,
        uint256 amount
    ) external override {
        require(_traders[trader].isActive, "Invalid trader");
        require(amount > 0, "Invalid amount");
        require(
            copyTrades[msg.sender][trader].amount == 0,
            "Already copy trading"
        );

        copyTrades[msg.sender][trader] = CopyTrading({
            follower: msg.sender,
            trader: trader,
            amount: amount,
            startTime: block.timestamp,
            lastCopyTime: block.timestamp,
            isActive: true
        });

        // Update follower counts and sets
        _traders[trader].followers++;
        followers[trader].add(msg.sender);
        following[msg.sender].add(trader);

        emit CopyTradeStarted(msg.sender, trader, amount);
    }

    /**
     * @notice Stops copy trading a trader
     * @param trader Address of trader to stop copying
     */
    function stopCopyTrading(address trader) external override {
        CopyTrading storage copyTrade = copyTrades[msg.sender][trader];
        require(copyTrade.isActive, "Not copy trading");

        copyTrade.isActive = false;
        _traders[trader].followers--;
        followers[trader].remove(msg.sender);
        following[msg.sender].remove(trader);

        emit CopyTradeStopped(msg.sender, trader);
    }

    /**
     * @notice Records a trade and updates trader reputation
     * @param trader Address of trader
     * @param volume Trade volume
     * @param success Whether trade was successful
     */
    function recordTrade(
        address trader,
        uint256 volume,
        bool success
    ) external override {
        require(msg.sender == registry.getContractAddress(keccak256(abi.encodePacked("CONTROLLER"))), "Unauthorized");
        require(_traders[trader].isActive, "Invalid trader");

        Trader storage traderData = _traders[trader];
        traderData.totalTrades++;
        traderData.totalVolume += volume;

        if (success) {
            traderData.successfulTrades++;
            // Update reputation based on success rate and volume
            uint256 successRate = (traderData.successfulTrades * 100) /
                traderData.totalTrades;
            uint256 volumeBonus = (volume * 10) / 1e18; // Scale volume bonus
            traderData.reputation =
                MIN_REPUTATION_SCORE +
                (successRate * REPUTATION_MULTIPLIER) +
                volumeBonus;
        }

        emit TradeExecuted(trader, address(0), keccak256(abi.encodePacked(block.timestamp, volume)));
        emit ReputationUpdated(trader, traderData.reputation);
    }

    /**
     * @notice Gets all traders being followed by a user
     * @param user Address of user
     * @return Array of trader addresses
     */
    function getFollowing(
        address user
    ) external view override returns (address[] memory) {
        return following[user].values();
    }

    /**
     * @notice Gets all followers of a trader
     * @param trader Address of trader
     * @return Array of follower addresses
     */
    function getFollowers(
        address trader
    ) external view override returns (address[] memory) {
        return followers[trader].values();
    }

    /**
     * @notice Gets trader details
     * @param trader Address of trader
     * @return Trader details
     */
    function getTrader(
        address trader
    ) external view override returns (Trader memory) {
        return _traders[trader];
    }

    /**
     * @notice Gets copy trading details
     * @param follower Address of follower
     * @param trader Address of trader
     * @return Copy trading details
     */
    function getCopyTrading(
        address follower,
        address trader
    ) external view override returns (CopyTrading memory) {
        return copyTrades[follower][trader];
    }

    /**
     * @notice Gets strategy details
     * @param strategyId Strategy ID
     * @return Strategy details
     */
    function strategies(
        bytes32 strategyId
    ) external view override returns (Strategy memory) {
        return _strategies[strategyId];
    }

    /**
     * @notice Gets trader details
     * @param trader Address of trader
     * @return Trader details
     */
    function traders(address trader) external view override returns (Trader memory) {
        return _traders[trader];
    }

    /**
     * @notice Gets all active strategies for a trader
     * @param trader Address of trader
     * @return Array of strategies
     */
    function _getTraderStrategies(
        address trader
    ) internal view returns (Strategy[] memory) {
        bytes32[] memory strategyIds = traderStrategies[trader].values();
        Strategy[] memory result = new Strategy[](strategyIds.length);

        for (uint i = 0; i < strategyIds.length; i++) {
            result[i] = _strategies[strategyIds[i]];
        }

        return result;
    }

    /**
     * @notice Calculates and distributes performance fees
     * @param trader Address of trader
     * @param profit Amount of profit generated
     */
    function _distributePerformanceFees(address trader, uint256 profit) internal {
        Strategy[] memory activeStrategies = _getTraderStrategies(trader);
        
        for (uint i = 0; i < activeStrategies.length; i++) {
            Strategy memory currentStrategy = activeStrategies[i];
            if (currentStrategy.isActive) {
                uint256 fee = (profit * currentStrategy.performanceFee) / 10000;
                if (fee > 0) {
                    // Transfer fee to trader
                    emit PerformanceFeePaid(trader, msg.sender, fee);
                }
            }
        }
    }
} 