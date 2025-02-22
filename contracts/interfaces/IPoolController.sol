// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPoolController {
    struct PoolConfig {
        address poolAddress;
        uint256 initialLiquidity;
        uint256 minLiquidity;
        uint256 maxLiquidity;
        uint256 lockDuration;
        uint16 swapFee;
        bool tradingEnabled;
        bool autoLiquidity;
    }

    struct PoolInfo {
        address poolAddress;
        uint256 tokenReserve;
        uint256 ethReserve;
        uint256 totalLiquidity;
        bool tradingEnabled;
        uint256 lockEnd;
    }
    
    event PoolCreated(address indexed token, address indexed pool, PoolConfig config);
    event LiquidityAdded(address indexed token, uint256 tokenAmount, uint256 ethAmount);
    event LiquidityRemoved(address indexed token, uint256 tokenAmount, uint256 ethAmount);
    event TradingEnabled(address indexed token);
    event TradingDisabled(address indexed token);
    
    function createPool(
        address token,
        PoolConfig memory config,
        address owner
    ) external returns (address);
    function addLiquidity(address token, uint256 tokenAmount) external payable;
    function removeLiquidity(address token, uint256 liquidity) external;
    function enableTrading(address token) external;
    function disableTrading(address token) external;
    function getPoolInfo(address token) external view returns (
        address poolAddress,
        uint256 tokenReserve,
        uint256 ethReserve,
        uint256 totalLiquidity,
        bool tradingEnabled,
        uint256 lockEnd
    );
    function setDependencies(
        address factory,
        address registry,
        address curve
    ) external;
    function initializePool(address token, PoolConfig memory config, address liquidityProvider) external payable;
    function getActivePools() external view returns (address[] memory);
    function pauseAll() external;
    function unpauseAll() external;
    function getUserPools(address user) external view returns (address[] memory);
} 