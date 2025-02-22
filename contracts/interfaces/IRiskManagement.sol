// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRiskManagement {
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

    event RiskParametersUpdated(address indexed token, RiskParameters params);
    event RiskScoreUpdated(address indexed token, uint256 newScore);
    event MarketDataUpdated(address indexed token, uint256 price, uint256 volume);
    event RiskAlert(address indexed token, string alertType, uint256 severity);
    event ParameterAdjusted(address indexed token, string parameter, uint256 oldValue, uint256 newValue);

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
    ) external;

    /**
     * @notice Sets risk parameters for a token
     * @param token Token address
     * @param params Risk parameters
     */
    function setRiskParameters(
        address token,
        RiskParameters calldata params
    ) external;

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
    ) external view returns (bool allowed, uint256 adjustedAmount);

    /**
     * @notice Gets current risk score for a token
     * @param token Token address
     * @return score The current risk score
     */
    function getRiskScore(address token) external view returns (RiskScore memory);

    /**
     * @notice Gets market data for a token
     * @param token Token address
     * @return data The market data
     */
    function getMarketData(address token) external view returns (MarketData memory);

    /**
     * @notice Gets risk parameters for a token
     * @param token Token address
     * @return params The risk parameters
     */
    function riskParams(address token) external view returns (RiskParameters memory);

    /**
     * @notice Gets last action time for a token
     * @param token Token address
     * @return timestamp The last action timestamp
     */
    function lastActionTime(address token) external view returns (uint256);
} 