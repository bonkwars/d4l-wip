// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IHydraGovernance.sol";

import "./libraries/HydraMath.sol";
import "./libraries/HydraCurve.sol";


contract HydraAMM {
    using HydraMath for uint256;
    
    struct Pool {
        uint256 x;           // Token X reserve
        uint256 y;           // Token Y reserve
        uint256 totalShares; // Total LP shares
        uint256 targetPrice; // Target price
        address lpToken;     // LP token address
    }
    
    address public immutable factory;
    IHydraGovernance public governance;

    
    mapping(address => mapping(address => Pool)) public pools;
    mapping(bytes32 => uint256) public parameters;
    
    event PoolCreated(address indexed tokenX, address indexed tokenY, address lpToken);
    event SwapExecuted(address indexed trader, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event LiquidityAdded(address indexed provider, uint256 shares, uint256 amountX, uint256 amountY);
    event ParameterUpdated(bytes32 indexed parameter, uint256 newValue);

    modifier onlyGovernance() {
        require(msg.sender == address(governance), "Unauthorized");
        _;
    }

    constructor(address _governance) {
        factory = msg.sender;
        governance = IHydraGovernance(_governance);
        _initializeParameters();
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external {
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
        
        pools[tokenA][tokenB] = Pool({
            x: amountA,
            y: amountB,
            totalShares: amountA * amountB,
            targetPrice: 0,
            lpToken: address(0)
        });
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        Pool storage pool = _getPool(tokenIn, tokenOut);
        
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        uint256 fee = (amountIn * parameters["feeRate"]) / 1e18;
        uint256 netInput = amountIn - fee;
        
        (uint256 newX, uint256 newY) = tokenIn < tokenOut 
            ? (pool.x + netInput, pool.y - _calculateOutput(pool, netInput, true))
            : (pool.x - _calculateOutput(pool, netInput, false), pool.y + netInput);
        
        pool.x = newX;
        pool.y = newY;
        
        IERC20(tokenOut).transfer(msg.sender, amountOut);
        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function _calculateOutput(Pool memory pool, uint256 input, bool isX) internal view returns (uint256) {
        uint256 z = isX 
            ? HydraMath.calculateZ(
                pool.y + input,
                pool.x
            )
            : HydraMath.calculateZ(
                pool.x + input,
                pool.y
            );
        
        uint256 liquidity = HydraMath.calculateLiquidity(
            z,
            parameters["sigmoidSteepness"],
            parameters["gaussianWidth"],
            parameters["rationalPower"]
        );
        
        return input * liquidity / 1e18;
    }

    function _initializeParameters() internal {
        parameters["feeRate"] = 0.003e18; // 0.3%
        parameters["sigmoidSteepness"] = 20e18;
        parameters["gaussianWidth"] = 0.15e18;
        parameters["rationalPower"] = 3e18;
        parameters["sigmoidWeight"] = 0.6e18;
        parameters["gaussianWeight"] = 0.3e18;
        parameters["rationalWeight"] = 0.1e18;
        parameters["baseAmplification"] = 1.35e18;
    }

    function updateParameter(bytes32 parameter, uint256 newValue) external onlyGovernance {
        parameters[parameter] = newValue;
        emit ParameterUpdated(parameter, newValue);
    }

    function _getPool(address tokenA, address tokenB) internal view returns (Pool storage) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        Pool storage pool = pools[token0][token1];
        require(pool.totalShares > 0, "Pool does not exist");
        return pool;
    }

    function calculateInitialDeposit(uint256 tokenAmount) public view returns (uint256) {
        // Constant product formula: x * y = k
        uint256 basePrice = 0.01 ether; // 0.01 WETH per token base
        return tokenAmount * basePrice;
    }

    function getSwapQuote(
        uint256 currentSupply,
        uint256 tokenAmount
    ) external pure returns (
        uint256 wethRequired,
        uint256 slippage
    ) {
        (wethRequired, slippage) = HydraCurve.quoteTrade(
            currentSupply,
            tokenAmount
        );
    }
} 