// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISwapRouter {
    // Events
    event CallerWhitelisted(address indexed caller, bool status);
    event SwapRouted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    // External functions
    function routeSwapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function routeSwapExactETHForTokens(
        address tokenOut,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function routeSwapExactTokensForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address payable to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    // View functions
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256);

    function getPriceImpact(
        address token,
        uint256 amount,
        bool isBuy
    ) external view returns (uint256);

    // Admin functions
    function setWhitelistedCaller(address caller, bool status) external;
    function setDEX(address _dex) external;
    function pause() external;
    function unpause() external;

    // Emergency functions
    function rescueTokens(
        address token,
        address to,
        uint256 amount
    ) external;

    function rescueETH(
        address payable to,
        uint256 amount
    ) external;
} 