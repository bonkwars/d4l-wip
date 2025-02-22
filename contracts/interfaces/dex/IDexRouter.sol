// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IDex.sol";

interface IDexRouter {
    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        IDex.Fees calldata fees
    ) external returns (uint256 amountOut);

    function executeETHSwap(
        address tokenOut,
        uint256 minAmountOut,
        address to,
        IDex.Fees calldata fees
    ) external payable returns (uint256 amountOut);

    function executeTokenToETHSwap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address payable to,
        IDex.Fees calldata fees
    ) external returns (uint256 amountOut);

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
} 