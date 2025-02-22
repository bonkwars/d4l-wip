// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IDegenDEX.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockDEX is IDegenDEX {
    mapping(address => mapping(address => Pool)) public pools;
    mapping(address => mapping(address => address)) public getPoolAddress;

    function createPool(
        address token0,
        address token1,
        uint256 fee
    ) external override returns (address) {
        require(token0 != token1, "Identical tokens");
        require(fee <= 10000, "Fee too high"); // Max 10%

        (address token0Sorted, address token1Sorted) = token0 < token1 
            ? (token0, token1) 
            : (token1, token0);

        require(getPoolAddress[token0Sorted][token1Sorted] == address(0), "Pool exists");

        // Create pool address deterministically
        address poolAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            token0Sorted,
            token1Sorted,
            fee,
            block.timestamp
        )))));

        pools[token0Sorted][token1Sorted] = Pool({
            token0: token0Sorted,
            token1: token1Sorted,
            reserve0: 0,
            reserve1: 0,
            totalSupply: 0,
            fee: fee
        });

        getPoolAddress[token0Sorted][token1Sorted] = poolAddress;
        getPoolAddress[token1Sorted][token0Sorted] = poolAddress;

        emit PoolCreated(token0Sorted, token1Sorted, poolAddress, fee);
        return poolAddress;
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
    ) external override returns (uint256 amount0, uint256 amount1, uint256 liquidity) {
        require(block.timestamp <= deadline, "Expired");
        require(amount0Desired >= amount0Min, "Insufficient amount0");
        require(amount1Desired >= amount1Min, "Insufficient amount1");

        (address token0Sorted, address token1Sorted) = token0 < token1 
            ? (token0, token1) 
            : (token1, token0);

        Pool storage pool = pools[token0Sorted][token1Sorted];
        require(pool.fee > 0, "Pool not found");

        // Transfer tokens
        IERC20(token0).transferFrom(msg.sender, address(this), amount0Desired);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1Desired);

        // Update reserves
        pool.reserve0 += amount0Desired;
        pool.reserve1 += amount1Desired;
        pool.totalSupply += amount0Desired; // Simplified LP calculation

        emit LiquidityAdded(msg.sender, token0, token1, amount0Desired, amount1Desired, amount0Desired);
        return (amount0Desired, amount1Desired, amount0Desired);
    }

    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external override returns (uint256 amount0, uint256 amount1) {
        require(block.timestamp <= deadline, "Expired");

        (address token0Sorted, address token1Sorted) = token0 < token1 
            ? (token0, token1) 
            : (token1, token0);

        Pool storage pool = pools[token0Sorted][token1Sorted];
        require(pool.fee > 0, "Pool not found");

        // Calculate amounts
        amount0 = (liquidity * pool.reserve0) / pool.totalSupply;
        amount1 = (liquidity * pool.reserve1) / pool.totalSupply;

        require(amount0 >= amount0Min, "Insufficient amount0");
        require(amount1 >= amount1Min, "Insufficient amount1");

        // Update reserves
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        pool.totalSupply -= liquidity;

        // Transfer tokens
        IERC20(token0).transfer(to, amount0);
        IERC20(token1).transfer(to, amount1);

        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, liquidity);
        return (amount0, amount1);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory amounts) {
        require(block.timestamp <= deadline, "Expired");
        require(path.length >= 2, "Invalid path");

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint i = 0; i < path.length - 1; i++) {
            (address token0, address token1) = path[i] < path[i + 1] 
                ? (path[i], path[i + 1]) 
                : (path[i + 1], path[i]);

            Pool storage pool = pools[token0][token1];
            require(pool.fee > 0, "Pool not found");

            // Simple constant product formula
            uint256 amountOut = (amountIn * pool.reserve1 * (10000 - pool.fee)) / (pool.reserve0 * 10000 + amountIn * (10000 - pool.fee));
            require(amountOut >= amountOutMin, "Insufficient output");

            amounts[i + 1] = amountOut;

            // Transfer tokens
            IERC20(path[i]).transferFrom(msg.sender, address(this), amountIn);
            IERC20(path[i + 1]).transfer(to, amountOut);

            // Update reserves
            if (path[i] == token0) {
                pool.reserve0 += amountIn;
                pool.reserve1 -= amountOut;
            } else {
                pool.reserve1 += amountIn;
                pool.reserve0 -= amountOut;
            }

            emit Swap(msg.sender, path[i], path[i + 1], amountIn, amountOut);
            amountIn = amountOut;
        }

        return amounts;
    }

    function getPool(
        address token0,
        address token1
    ) external view override returns (Pool memory) {
        (address token0Sorted, address token1Sorted) = token0 < token1 
            ? (token0, token1) 
            : (token1, token0);
        return pools[token0Sorted][token1Sorted];
    }

    function getPoolInfo(
        address token0,
        address token1
    ) external view returns (Pool memory) {
        (address token0Sorted, address token1Sorted) = token0 < token1 
            ? (token0, token1) 
            : (token1, token0);
        return pools[token0Sorted][token1Sorted];
    }

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view override returns (uint256) {
        (address token0, address token1) = tokenIn < tokenOut 
            ? (tokenIn, tokenOut) 
            : (tokenOut, tokenIn);

        Pool storage pool = pools[token0][token1];
        require(pool.fee > 0, "Pool not found");

        if (tokenIn == token0) {
            return (amountIn * pool.reserve1 * (10000 - pool.fee)) / (pool.reserve0 * 10000 + amountIn * (10000 - pool.fee));
        } else {
            return (amountIn * pool.reserve0 * (10000 - pool.fee)) / (pool.reserve1 * 10000 + amountIn * (10000 - pool.fee));
        }
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view override returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint i = 0; i < path.length - 1; i++) {
            amounts[i + 1] = this.getAmountOut(amounts[i], path[i], path[i + 1]);
        }

        return amounts;
    }
} 