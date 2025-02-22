// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILiquidityModule {

    event PoolInitialized(address indexed token, address indexed pool, PoolParameters params);

    struct PoolParameters {
        uint256 initialLiquidity;
        uint256 minLiquidity;
        uint256 maxLiquidity;
        uint256 lockDuration;
        uint16 swapFee;
        bool autoLiquidity;
    }

    function checkLiquidityLimits(
        address token,
        uint256 amount
    ) external view returns (bool);

   function initializePool(
    address token,
    PoolParameters calldata params,
    address liquidityProvider
) external payable;

    function initialize(address token, address registry) external;

    function pause() external;
    function unpause() external;

    function setFeeDistribution(
        address token,
        address communityPool, uint16 communityFee,
        address teamPool, uint16 teamFee,
        address dexLiquidityPool, uint16 dexLiquidityFee,
        address treasuryPool, uint16 treasuryFee,
        address marketingPool, uint16 marketingFee,
        address cexLiquidityPool, uint16 cexLiquidityFee
    ) external;
} 