// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IDegenDEX.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract MockDegenDEX is IDegenDEX, Pausable {
    function createPool(
        address token0,
        address token1,
        uint256 fee
    ) external override returns (address) {
        return address(0); // Mock implementation
    }
    
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external override returns (uint256, uint256, uint256) {
        return (0, 0, 0); // Mock implementation
    }
    
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](path.length);
        return amounts; // Mock implementation
    }

    function pause() external {
        _pause();
    }

    function unpause() external {
        _unpause();
    }

    function getPool(
        address token0,
        address token1
    ) external view override returns (Pool memory) {
        return Pool({
            token0: token0,
            token1: token1,
            reserve0: 0,
            reserve1: 0,
            totalSupply: 0,
            fee: 0
        }); // Mock implementation
    }

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view override returns (uint256) {
        return 0; // Mock implementation
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view override returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](path.length);
        return amounts; // Mock implementation
    }

    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external override returns (uint256, uint256) {
        return (0, 0); // Mock implementation
    }
} 