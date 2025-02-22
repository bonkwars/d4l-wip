// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILiquidityRouter
 * @notice Interface for the LiquidityRouter module that handles fee collection and distribution
 */
interface ILiquidityRouter {
    /**
     * @notice Collects fees from a transaction and distributes them to pools
     * @param token The token address
     * @param amount The total amount of fees to distribute
     */
    function collectAndDistributeFees(
        address token,
        uint256 amount
    ) external;
    
    /**
     * @notice Gets the fee distribution for a given amount
     * @param amount The amount to calculate fees for
     * @return communityAmount The amount allocated to community pool
     * @return teamAmount The amount allocated to team pool
     * @return dexLiquidityAmount The amount allocated to DEX liquidity pool
     * @return treasuryAmount The amount allocated to treasury
     * @return marketingAmount The amount allocated to marketing pool
     * @return cexLiquidityAmount The amount allocated to CEX liquidity pool
     * @return buybackAmount The amount allocated to buyback and burn
     */
    function calculateFeeDistribution(
        uint256 amount
    ) external pure returns (
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexLiquidityAmount,
        uint256 treasuryAmount,
        uint256 marketingAmount,
        uint256 cexLiquidityAmount,
        uint256 buybackAmount
    );
    
    /**
     * @notice Gets the total fee percentage
     * @return totalFee Total fee in basis points (100 = 1%)
     */
    function getTotalFee() external pure returns (uint16 totalFee);
    
    /**
     * @notice Gets the individual fee percentages
     * @return communityFee Percentage for community pool (20%)
     * @return teamFee Percentage for team pool (15%)
     * @return dexLiquidityFee Percentage for DEX liquidity pool (25%)
     * @return treasuryFee Percentage for treasury (10%)
     * @return marketingFee Percentage for marketing pool (10%)
     * @return cexLiquidityFee Percentage for CEX liquidity pool (5%)
     * @return buybackFee Percentage for buyback and burn (15%)
     */
    function getFeePercentages() external pure returns (
        uint16 communityFee,
        uint16 teamFee,
        uint16 dexLiquidityFee,
        uint16 treasuryFee,
        uint16 marketingFee,
        uint16 cexLiquidityFee,
        uint16 buybackFee
    );

    /**
     * @notice Event emitted when fees are collected
     * @param token The token address
     * @param from The address fees were collected from
     * @param amount The amount of fees collected
     * @param timestamp When the fees were collected
     */
    event FeesCollected(
        address indexed token,
        address indexed from,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @notice Event emitted when fees are distributed
     * @param token The token address
     * @param communityAmount Amount sent to community pool
     * @param teamAmount Amount sent to team pool
     * @param dexLiquidityAmount Amount sent to DEX liquidity pool
     * @param treasuryAmount Amount sent to treasury
     * @param marketingAmount Amount sent to marketing pool
     * @param cexLiquidityAmount Amount sent to CEX liquidity pool
     * @param buybackAmount Amount used for buyback and burn
     */
    event FeesDistributed(
        address indexed token,
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexLiquidityAmount,
        uint256 treasuryAmount,
        uint256 marketingAmount,
        uint256 cexLiquidityAmount,
        uint256 buybackAmount
    );

    /**
     * @notice Event emitted when tokens are bought back
     * @param token The token address
     * @param amountSpent Amount of tokens spent on buyback
     * @param tokensBought Amount of tokens bought back
     */
    event TokensBoughtBack(
        address indexed token,
        uint256 amountSpent,
        uint256 tokensBought
    );

    /**
     * @notice Event emitted when tokens are burned
     * @param token The token address
     * @param amount Amount of tokens burned
     */
    event TokensBurned(
        address indexed token,
        uint256 amount
    );
} 