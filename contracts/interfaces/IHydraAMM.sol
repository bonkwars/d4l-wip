// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHydraAMM {
    function calculateInitialDeposit(uint256 tokenAmount) external view returns (uint256);
    function createPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external;
    function getSwapQuote(
        uint256 currentSupply,
        uint256 tokenAmount
    ) external pure returns (
        uint256 wethRequired,
        uint256 slippage
    );
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256 amountOut);

     function swap(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);


} 