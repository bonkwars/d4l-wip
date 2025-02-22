// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IHydraAMM.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockHydraAMM is IHydraAMM {
    address public immutable owner;
    mapping(address => uint256) public reserves;

    constructor() {
        owner = msg.sender;
    }

    function calculateInitialDeposit(uint256 tokenAmount) external pure returns (uint256) {
        return tokenAmount / 2; // Mock implementation
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external {
        reserves[tokenA] = amountA;
        reserves[tokenB] = amountB;
    }

    function getSwapQuote(
        uint256 currentSupply,
        uint256 tokenAmount
    ) external pure returns (
        uint256 wethRequired,
        uint256 slippage
    ) {
        wethRequired = (tokenAmount * currentSupply) / 1e18;
        slippage = 100; // 1% slippage
        return (wethRequired, slippage);
    }

    function swap(
        address token,
        address to,
        uint256 amount
    ) external returns (uint256) {
        // For testing, just burn the tokens to simulate a swap
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        // Burn the tokens by sending them to the zero address
        IERC20(token).transfer(address(0), amount);
        return amount;
    }

    function swap(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        // Transfer input tokens from sender to this contract
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        
        // Return tokens to the recipient
        IERC20(path[0]).transfer(to, amountIn);
        
        // Return amounts array
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[1] = amountIn; // Return same amount for testing
        return amounts;
    }

    function addLiquidity(
        address token,
        uint256 tokenAmount,
        uint256 ethAmount
    ) external payable returns (uint256) {
        return tokenAmount;
    }

    function removeLiquidity(
        address token,
        uint256 liquidity
    ) external returns (uint256, uint256) {
        return (liquidity, liquidity);
    }

    function getReserves(
        address token
    ) external view returns (uint256, uint256) {
        return (reserves[token], reserves[token]);
    }

    function getAmountOut(
        address token,
        uint256 amountIn
    ) external pure returns (uint256) {
        return amountIn;
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        return amounts;
    }

    // Helper function to set reserves for testing
    function setReserve(address token, uint256 amount) external {
        reserves[token] = amount;
    }

    // Add receive function to accept ETH
    receive() external payable {}
}