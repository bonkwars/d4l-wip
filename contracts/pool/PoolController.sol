// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solmate/src/auth/Owned.sol";
import "solmate/src/tokens/ERC20.sol";
import "../interfaces/IPoolController.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IFeeHandler.sol";
import "../interfaces/IUserProfile.sol";

/// @title PoolController
/// @notice Manages liquidity pools for tokens
/// @dev Handles pool creation, liquidity management, and trading
contract PoolController is Owned {
    // Constants
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_LIQUIDITY = 1000;
    
    // Immutables
    IUniswapV2Router02 public immutable router;
    IUniswapV2Factory public immutable factory;
    address public immutable WETH;
    address public immutable feeHandler;
    address public immutable userProfile;
    
    // Structs
    struct PoolConfig {
        uint256 initialLiquidity;
        uint256 minLiquidity;
        uint256 maxLiquidity;
        uint256 lockDuration;
        uint16 swapFee;
        bool tradingEnabled;
        bool autoLiquidity;
    }
    
    // State variables
    mapping(address => PoolConfig) public poolConfigs;
    mapping(address => address) public pools;
    mapping(address => uint256) public liquidityLocks;
    address[] public activePools;
    
    // Events
    event PoolCreated(address indexed token, address indexed pool, PoolConfig config);
    event LiquidityAdded(address indexed token, uint256 tokenAmount, uint256 ethAmount);
    event LiquidityRemoved(address indexed token, uint256 tokenAmount, uint256 ethAmount);
    event TradingEnabled(address indexed token);
    event TradingDisabled(address indexed token);
    
    constructor(
        address _router,
        address _factory,
        address _weth,
        address _feeHandler,
        address _userProfile
    ) Owned(msg.sender) {
        router = IUniswapV2Router02(_router);
        factory = IUniswapV2Factory(_factory);
        WETH = _weth;
        feeHandler = _feeHandler;
        userProfile = _userProfile;
    }
    
    /// @notice Creates a new liquidity pool
    function createPool(
        address tokenA,
        address tokenB,
        address lpToken
    ) external {
        require(pools[tokenA] == address(0), "Pool exists");
        
        // Create pool using factory
        address pool = factory.createPair(tokenA, tokenB);
        pools[tokenA] = pool;
        
        // Add to active pools
        activePools.push(tokenA);
        
        emit PoolCreated(tokenA, pool, poolConfigs[tokenA]);
    }
    
    /// @notice Adds liquidity to a pool
    function addLiquidity(
        address token,
        uint256 tokenAmount
    ) external payable {
        require(pools[token] != address(0), "Pool not found");
        PoolConfig storage config = poolConfigs[token];
        
        // Calculate amounts
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pools[token]).getReserves();
        uint256 ethAmount = msg.value;
        
        // Check limits
        require(reserve0 + tokenAmount <= config.maxLiquidity, "Exceeds max liquidity");
        require(reserve1 + ethAmount <= config.maxLiquidity, "Exceeds max liquidity");
        
        // Add liquidity
        ERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
        router.addLiquidityETH{value: ethAmount}(
            token,
            tokenAmount,
            0, // slippage: accept any amount of tokens
            0, // slippage: accept any amount of ETH
            msg.sender,
            block.timestamp
        );
        
        // Automatic fee handling
        IFeeHandler(feeHandler).distributeTaxes(
            token,
            tokenAmount
        );
        
        // Update user profile stats
        IUserProfile(userProfile).updateLiquidityStats(
            
            msg.sender,
            token,
            tokenAmount
        );
        
        emit LiquidityAdded(token, tokenAmount, ethAmount);
    }
    
    /// @notice Removes liquidity from a pool
    function removeLiquidity(
        address token,
        uint256 liquidity
    ) external {
        require(pools[token] != address(0), "Pool not found");
        require(block.timestamp >= liquidityLocks[token], "Liquidity locked");
        
        // Remove liquidity
        IUniswapV2Pair pair = IUniswapV2Pair(pools[token]);
        pair.transferFrom(msg.sender, address(this), liquidity);
        pair.approve(address(router), liquidity);
        
        (uint256 tokenAmount, uint256 ethAmount) = router.removeLiquidityETH(
            token,
            liquidity,
            0, // slippage: accept any amount of tokens
            0, // slippage: accept any amount of ETH
            msg.sender,
            block.timestamp
        );
        
        emit LiquidityRemoved(token, tokenAmount, ethAmount);
    }
    
    /// @notice Enables trading for a token
    function enableTrading(address token) external {
        require(msg.sender == Owned(token).owner(), "Not token owner");
        require(pools[token] != address(0), "Pool not found");
        
        PoolConfig storage config = poolConfigs[token];
        require(!config.tradingEnabled, "Already enabled");
        
        config.tradingEnabled = true;
        emit TradingEnabled(token);
    }
    
    /// @notice Disables trading for a token
    function disableTrading(address token) external {
        require(msg.sender == Owned(token).owner(), "Not token owner");
        require(pools[token] != address(0), "Pool not found");
        
        PoolConfig storage config = poolConfigs[token];
        require(config.tradingEnabled, "Already disabled");
        
        config.tradingEnabled = false;
        emit TradingDisabled(token);
    }
    
    /// @notice Gets pool information
    function getPoolInfo(
        address token
    ) external view returns (
        address pool,
        uint256 tokenReserve,
        uint256 ethReserve,
        uint256 totalLiquidity,
        bool tradingEnabled,
        uint256 lockEnd
    ) {
        pool = pools[token];
        require(pool != address(0), "Pool not found");
        
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pool).getReserves();
        tokenReserve = reserve0;
        ethReserve = reserve1;
        totalLiquidity = IUniswapV2Pair(pool).totalSupply();
        tradingEnabled = poolConfigs[token].tradingEnabled;
        lockEnd = liquidityLocks[token];
    }
    
    /// @notice Gets all active pools
    function getActivePools() external view returns (address[] memory) {
        return activePools;
    }
    
    /// @notice Pauses all pools
    function pauseAll() external onlyOwner {
        for (uint256 i = 0; i < activePools.length; i++) {
            address token = activePools[i];
            if (poolConfigs[token].tradingEnabled) {
                poolConfigs[token].tradingEnabled = false;
                emit TradingDisabled(token);
            }
        }
    }

    /// @notice Unpauses all pools
    function unpauseAll() external onlyOwner {
        for (uint256 i = 0; i < activePools.length; i++) {
            address token = activePools[i];
            if (!poolConfigs[token].tradingEnabled) {
                poolConfigs[token].tradingEnabled = true;
                emit TradingEnabled(token);
            }
        }
    }
    
    /// @notice Initializes a pool with configuration
    function initializePool(address token, PoolConfig memory config) external payable {
        require(pools[token] == address(0), "Pool exists");
        require(config.initialLiquidity > 0, "Invalid initial liquidity");
        require(config.minLiquidity > 0, "Invalid min liquidity");
        require(config.maxLiquidity > config.minLiquidity, "Invalid max liquidity");
        require(config.lockDuration > 0, "Invalid lock duration");
        require(msg.value >= config.initialLiquidity, "Insufficient ETH for initial liquidity");
        
        // Create pool using factory
        address pool = factory.createPair(token, WETH);
        pools[token] = pool;
        poolConfigs[token] = config;
        
        // Set liquidity lock
        liquidityLocks[token] = block.timestamp + config.lockDuration;
        
        // Add to active pools
        activePools.push(token);
        
        // Initialize pool with liquidity
        if (config.initialLiquidity > 0) {
            // Get token from caller
            ERC20(token).transferFrom(msg.sender, address(this), config.initialLiquidity);
            
            // Approve router to spend tokens
            ERC20(token).approve(address(router), config.initialLiquidity);
            
            // Add initial liquidity
            router.addLiquidityETH{value: config.initialLiquidity}(
                token,
                config.initialLiquidity,
                0, // slippage: accept any amount of tokens
                0, // slippage: accept any amount of ETH
                msg.sender, // LP tokens go to the caller
                block.timestamp
            );
            
            // Refund excess ETH if any
            if (msg.value > config.initialLiquidity) {
                payable(msg.sender).transfer(msg.value - config.initialLiquidity);
            }
        }
        
        emit PoolCreated(token, pool, config);
    }
    
    receive() external payable {}
} 