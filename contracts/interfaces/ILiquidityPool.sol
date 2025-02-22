// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface ILiquidityPool {
    struct PoolInfo {
        address token;          // 20 bytes
        address lpToken;        // 20 bytes
        uint256 tokenReserve;  // 32 bytes
        uint256 ethReserve;    // 32 bytes
        uint256 totalLiquidity;// 32 bytes
        uint256 lastUpdateTime;// 32 bytes
        uint256 lockDuration;  // 32 bytes
        uint256 fee;          // 32 bytes
        uint8 status;         // 1 byte
    }

    struct SwapParams {
        uint96 amountIn;
        uint96 minAmountOut;
        uint256 deadline;
    }

    struct LiquidityParams {
        uint96 amount;
        uint256 deadline;
        uint96 minLiquidity;
    }

    event PoolCreated(
        address indexed token,
        uint256 initialLiquidity,
        uint256 lockDuration,
        uint256 swapFee
    );

    event LiquidityAdded(
        address indexed token,
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed token,
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event Swap(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint96 amountIn,
        uint96 amountOut
    );

    event PoolStatusUpdated(
        address indexed token,
        uint8 status
    );

    event SwapFeeUpdated(address indexed token, uint256 newFee);
    event AutoLiquidityUpdated(address indexed token, bool enabled);

    /// @notice Creates a new liquidity pool for a token
    /// @param token The token address
    /// @param tokenAmount Initial token amount
    /// @param ethAmount Initial ETH amount
    /// @param lockDuration Duration for liquidity lock
    /// @param swapFee Swap fee in basis points
    /// @param autoLiquidity Whether liquidity is automatically added
    /// @return lpToken The address of the LP token
    function createPool(
        address token,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 lockDuration,
        uint256 swapFee,
        bool autoLiquidity
    ) external payable returns (address lpToken);

    /// @notice Adds liquidity to a pool
    /// @param token The token address
    /// @param minTokenAmount Minimum amount of tokens to add
    /// @param minEthAmount Minimum amount of ETH to add
    /// @return liquidity Amount of liquidity added
    function addLiquidity(
        address token,
        uint256 minTokenAmount,
        uint256 minEthAmount
    ) external payable returns (uint256 liquidity);

    /// @notice Removes liquidity from a pool
    /// @param token The token address
    /// @param liquidity Amount of liquidity to remove
    /// @param minTokenAmount Minimum amount of tokens to return
    /// @param minEthAmount Minimum amount of ETH to return
    /// @return tokenAmount Amount of tokens returned
    /// @return ethAmount Amount of ETH returned
    function removeLiquidity(
        address token,
        uint256 liquidity,
        uint256 minTokenAmount,
        uint256 minEthAmount
    ) external returns (uint256 tokenAmount, uint256 ethAmount);

    /// @notice Swaps tokens using the pool
    /// @param tokenIn Address of input token
    /// @param tokenOut Address of output token
    /// @param params Swap parameters
    /// @return amountOut Amount of output tokens
    function swap(
        address tokenIn,
        address tokenOut,
        SwapParams calldata params
    ) external payable returns (uint96 amountOut);

    /// @notice Gets the current reserves for a pool
    /// @param token The token address
    /// @return tokenReserve Current token reserve
    /// @return ethReserve Current ETH reserve
    /// @return totalLiquidity Total liquidity in the pool
    /// @return lastUpdateTime Timestamp of the last update
    /// @return lockDuration Duration for liquidity lock
    /// @return swapFee Swap fee in basis points
    /// @return autoLiquidity Whether liquidity is automatically added
    function getPool(address token) external view returns (
        uint256 tokenReserve,
        uint256 ethReserve,
        uint256 totalLiquidity,
        uint256 lastUpdateTime,
        uint256 lockDuration,
        uint256 swapFee,
        bool autoLiquidity
    );

    /// @notice Calculates the output amount for a swap
    /// @param tokenIn Address of input token
    /// @param tokenOut Address of output token
    /// @param amountIn Amount of input tokens
    /// @return amountOut Expected output amount
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    /// @notice Gets pool information
    /// @param token The token address
    function getPoolInfo(address token) external view returns (PoolInfo memory);

    /// @notice Updates pool status
    /// @param token The token address
    /// @param status New status flags
    function updatePoolStatus(address token, uint8 status) external;

    /// @notice Checks if a pool exists for a token
    /// @param token The token address
    function poolExists(address token) external view returns (bool);

    /// @notice Gets the optimal swap amount out
    /// @param tokenIn Address of input token
    /// @param amountIn Amount of input tokens
    /// @param reserveIn Reserve of input token
    /// @param reserveOut Reserve of output token
    /// @return amountOut Optimal output amount
    function getOptimalSwapAmount(
        address tokenIn,
        uint96 amountIn,
        uint96 reserveIn,
        uint96 reserveOut
    ) external view returns (uint96 amountOut);

    /// @notice Gets the liquidity balance for a provider in a pool
    /// @param token The token address
    /// @param provider The provider address
    /// @return liquidityBalance Liquidity balance for the provider
    function liquidityBalance(address token, address provider) external view returns (uint256);

    /// @notice Gets the pool information for a token
    /// @param token The token address
    /// @return tokenReserve Current token reserve
    /// @return ethReserve Current ETH reserve
    /// @return totalLiquidity Total liquidity in the pool
    /// @return lastUpdateTime Timestamp of the last update
    /// @return lockDuration Duration for liquidity lock
    /// @return swapFee Swap fee in basis points
    /// @return autoLiquidity Whether liquidity is automatically added
    function pools(address token) external view returns (
        uint256 tokenReserve,
        uint256 ethReserve,
        uint256 totalLiquidity,
        uint256 lastUpdateTime,
        uint256 lockDuration,
        uint256 swapFee,
        bool autoLiquidity
    );
} 