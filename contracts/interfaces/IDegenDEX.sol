// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDegenDEX {
    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        uint256 fee;
    }

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        address pool,
        uint256 fee
    );

    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 lpTokens
    );

    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 lpTokens
    );

    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    function createPool(
        address token0,
        address token1,
        uint256 fee
    ) external returns (address);

    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1, uint256 liquidity);

    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getPool(
        address token0,
        address token1
    ) external view returns (Pool memory);

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
} 