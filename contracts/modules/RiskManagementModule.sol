// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "../interfaces/IContractRegistry.sol";
import "../interfaces/IRiskManagement.sol";

/**
 * @title RiskManagementModule
 * @notice AI-driven risk management system for DeFi operations
 */
contract RiskManagementModule is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    // State variables
    IContractRegistry public registry;
    
    struct RiskParameters {
        uint256 maxExposure;
        uint256 collateralRatio;
        uint256 liquidationThreshold;
        uint256 cooldownPeriod;
        uint256 volatilityThreshold;
        bool active;
    }

    struct RiskScore {
        uint256 baseScore;
        uint256 volatilityScore;
        uint256 liquidityScore;
        uint256 collateralScore;
        uint256 timestamp;
    }

    struct MarketData {
        uint256 price;
        uint256 volume24h;
        uint256 liquidity;
        uint256 volatility;
        uint256 lastUpdate;
    }

    // Mappings
    mapping(address => RiskParameters) public riskParams;
    mapping(address => RiskScore) public riskScores;
    mapping(address => MarketData) public marketData;
    mapping(address => uint256) public lastActionTime;
    
    // Constants
    uint256 public constant MAX_RISK_SCORE = 100;
    uint256 public constant MIN_UPDATE_INTERVAL = 1 hours;
    uint256 public constant VOLATILITY_WINDOW = 24 hours;
    uint256 public constant MAX_PRICE_DEVIATION = 1000; // 10%

    // Events
    event RiskParametersUpdated(address indexed token, RiskParameters params);
    event RiskScoreUpdated(address indexed token, uint256 newScore);
    event MarketDataUpdated(address indexed token, uint256 price, uint256 volume);
    event RiskAlert(address indexed token, string alertType, uint256 severity);
    event ParameterAdjusted(address indexed token, string parameter, uint256 oldValue, uint256 newValue);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _registry) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_registry != address(0), "Invalid registry");
        registry = IContractRegistry(_registry);
    }

    /**
     * @notice Updates market data for a token
     * @param token Token address
     * @param price Current price
     * @param volume24h 24h trading volume
     * @param liquidity Available liquidity
     */
    function updateMarketData(
        address token,
        uint256 price,
        uint256 volume24h,
        uint256 liquidity
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(price > 0, "Invalid price");
        
        MarketData storage data = marketData[token];
        
        // Calculate volatility
        uint256 volatility = 0;
        if (data.price > 0) {
            volatility = _calculateVolatility(price, data.price);
        }

        data.price = price;
        data.volume24h = volume24h;
        data.liquidity = liquidity;
        data.volatility = volatility;
        data.lastUpdate = block.timestamp;

        // Update risk score based on new data
        _updateRiskScore(token);

        emit MarketDataUpdated(token, price, volume24h);
    }

    /**
     * @notice Sets risk parameters for a token
     * @param token Token address
     * @param params Risk parameters
     */
    function setRiskParameters(
        address token,
        RiskParameters calldata params
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        
        riskParams[token] = params;
        emit RiskParametersUpdated(token, params);
    }

    /**
     * @notice Checks if an operation is within risk limits
     * @param token Token address
     * @param amount Operation amount
     * @return allowed Whether the operation is allowed
     * @return adjustedAmount Adjusted amount if needed
     */
    function checkRiskLimits(
        address token,
        uint256 amount
    ) external view returns (bool allowed, uint256 adjustedAmount) {
        RiskParameters storage params = riskParams[token];
        require(params.active, "Risk parameters not set");

        RiskScore storage score = riskScores[token];
        require(block.timestamp <= score.timestamp + MIN_UPDATE_INTERVAL, "Risk score outdated");

        // Calculate risk-adjusted amount
        uint256 riskFactor = score.baseScore * score.volatilityScore / MAX_RISK_SCORE;
        adjustedAmount = amount * riskFactor / MAX_RISK_SCORE;

        // Check if within limits
        allowed = adjustedAmount <= params.maxExposure &&
                 block.timestamp >= lastActionTime[token] + params.cooldownPeriod;

        return (allowed, adjustedAmount);
    }

    /**
     * @notice Gets current risk score for a token
     * @param token Token address
     * @return score The current risk score
     */
    function getRiskScore(address token) external view returns (RiskScore memory) {
        return riskScores[token];
    }

    /**
     * @notice Gets market data for a token
     * @param token Token address
     * @return data The market data
     */
    function getMarketData(address token) external view returns (MarketData memory) {
        return marketData[token];
    }

    // Internal functions

    function _updateRiskScore(address token) internal {
        MarketData storage data = marketData[token];
        RiskParameters storage params = riskParams[token];

        // Calculate component scores
        uint256 volatilityScore = _calculateVolatilityScore(data.volatility);
        uint256 liquidityScore = _calculateLiquidityScore(data.liquidity);
        uint256 volumeScore = _calculateVolumeScore(data.volume24h);

        // Update risk score
        RiskScore storage score = riskScores[token];
        score.baseScore = (volatilityScore + liquidityScore + volumeScore) / 3;
        score.volatilityScore = volatilityScore;
        score.liquidityScore = liquidityScore;
        score.timestamp = block.timestamp;

        emit RiskScoreUpdated(token, score.baseScore);

        // Check for risk alerts
        if (volatilityScore > params.volatilityThreshold) {
            emit RiskAlert(token, "High Volatility", volatilityScore);
        }
    }

    function _calculateVolatility(uint256 newPrice, uint256 oldPrice) internal pure returns (uint256) {
        if (newPrice > oldPrice) {
            return ((newPrice - oldPrice) * 10000) / oldPrice;
        } else {
            return ((oldPrice - newPrice) * 10000) / oldPrice;
        }
    }

    function _calculateVolatilityScore(uint256 volatility) internal pure returns (uint256) {
        return volatility > MAX_RISK_SCORE ? MAX_RISK_SCORE : volatility;
    }

    function _calculateLiquidityScore(uint256 liquidity) internal pure returns (uint256) {
        // Implementation needed: calculate score based on liquidity depth
        return MAX_RISK_SCORE;
    }

    function _calculateVolumeScore(uint256 volume) internal pure returns (uint256) {
        // Implementation needed: calculate score based on volume
        return MAX_RISK_SCORE;
    }
} 