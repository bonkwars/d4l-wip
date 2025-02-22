// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/ReentrancyGuard.sol";
import "solmate/src/tokens/ERC20.sol";
import "../interfaces/ILiquidityPool.sol";

abstract contract AbstractLiquidityPool is Owned, ReentrancyGuard, ILiquidityPool {
    // Mapping of token address to pool info
    mapping(address => PoolInfo) private _pools;
    
    // Minimum liquidity required to initialize a pool
    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    
    // Fee percentage (0.3%)
    uint256 private constant FEE_NUMERATOR = 3;
    uint256 private constant FEE_DENOMINATOR = 1000;

    // Add flash loan protection
    uint256 private constant MIN_BLOCK_DELAY = 1;
    mapping(address => uint256) private _lastTradeBlock;

    modifier flashLoanProtection(address account) {
        require(block.number > _lastTradeBlock[account] + MIN_BLOCK_DELAY, "Potential flash loan");
        _lastTradeBlock[account] = block.number;
        _;
    }

    // Add emergency stop functionality
    bool private _paused;
    
    event EmergencyStop(address indexed operator);
    event EmergencyResume(address indexed operator);

    modifier whenNotPaused() {
        require(!_paused, "Protocol is paused");
        _;
    }

    // Add rate limiting
    struct RateLimit {
        uint256 amount;
        uint256 lastUpdate;
        uint256 windowSize;
    }

    mapping(address => RateLimit) private _rateLimits;
    uint256 private constant RATE_LIMIT_WINDOW = 1 hours;
    uint256 private constant MAX_TRADE_AMOUNT_PER_WINDOW = 1000000e18; // Adjust based on token decimals

    modifier rateLimit(address account, uint256 amount) {
        RateLimit storage limit = _rateLimits[account];
        
        // Reset window if expired
        if (block.timestamp >= limit.lastUpdate + limit.windowSize) {
            limit.amount = 0;
            limit.lastUpdate = block.timestamp;
        }

        // Check and update limit
        require(limit.amount + amount <= MAX_TRADE_AMOUNT_PER_WINDOW, "Rate limit exceeded");
        limit.amount += amount;
        _;
    }

    // Add price impact protection
    uint256 private constant MAX_PRICE_IMPACT = 1000; // 10% in basis points

    constructor() Owned(msg.sender) {}

    /// @notice Creates a new liquidity pool for a token
    function createPool(
        address token,
        uint96 initialTokenAmount,
        uint96 initialEthAmount,
        uint32 lockDuration
    ) external payable virtual nonReentrant whenNotPaused returns (address lpToken) {
        require(initialTokenAmount > 0, "Invalid token amount");
        require(initialEthAmount > 0, "Invalid ETH amount");
        require(msg.value == initialEthAmount, "Invalid ETH sent");
        require(_pools[token].token == address(0), "Pool exists");

        // Create LP token
        lpToken = _createLPToken(token);

        // Transfer tokens
        ERC20(token).transferFrom(msg.sender, address(this), initialTokenAmount);

        // Initialize pool
        _pools[token] = PoolInfo({
            token: token,
            lpToken: lpToken,
            tokenReserve: initialTokenAmount,
            ethReserve: initialEthAmount,
            totalLiquidity: initialTokenAmount + initialEthAmount,
            lastUpdateTime: uint32(block.timestamp),
            lockDuration: lockDuration,
            fee: uint16(300), // 0.3%
            status: uint8(1)
        });

        emit PoolCreated(
            token,
            initialTokenAmount,
            initialEthAmount,
            uint32(block.timestamp + lockDuration)
        );
    }

    /// @notice Adds liquidity to a pool
    function addLiquidity(
        address token,
        LiquidityParams calldata params
    ) external payable virtual nonReentrant whenNotPaused returns (uint96 lpTokens) {
        require(block.timestamp <= params.deadline, "Transaction expired");
        PoolInfo storage pool = _pools[token];
        require(pool.status == 1, "Pool inactive");
        require(params.amount > 0, "Invalid amount");
        require(msg.value > 0, "Invalid ETH");
        require(params.amount >= MINIMUM_LIQUIDITY, "Insufficient liquidity");

        // Calculate optimal amounts
        (uint96 optimalTokenAmount, uint96 optimalEthAmount) = _calculateOptimalAmounts(
            pool,
            params.amount,
            uint96(msg.value)
        );

        // Check minimum liquidity
        require(optimalTokenAmount >= params.minLiquidity, "Insufficient token liquidity");
        require(optimalEthAmount >= params.minLiquidity, "Insufficient ETH liquidity");

        // Transfer tokens
        require(
            ERC20(token).transferFrom(msg.sender, address(this), optimalTokenAmount),
            "Token transfer failed"
        );

        // Update reserves
        pool.tokenReserve += optimalTokenAmount;
        pool.ethReserve += optimalEthAmount;
        pool.lastUpdateTime = uint32(block.timestamp);

        // Mint LP tokens
        lpTokens = _calculateLPTokens(pool, optimalTokenAmount, optimalEthAmount);
        _mintLPTokens(pool.lpToken, msg.sender, lpTokens);

        emit LiquidityAdded(
            token,
            msg.sender,
            optimalTokenAmount,
            optimalEthAmount,
            lpTokens
        );
    }

    /// @notice Removes liquidity from a pool
    function removeLiquidity(
        address token,
        uint96 lpTokenAmount,
        uint256 deadline,
        uint96 minTokenAmount,
        uint96 minEthAmount
    ) external virtual nonReentrant returns (uint96 tokenAmount, uint96 ethAmount) {
        require(block.timestamp <= deadline, "Transaction expired");
        PoolInfo storage pool = _pools[token];
        require(pool.status == 1, "Pool inactive");
        require(lpTokenAmount > 0, "Invalid amount");

        // Calculate amounts
        uint256 totalSupply = ERC20(pool.lpToken).totalSupply();
        tokenAmount = uint96((uint256(pool.tokenReserve) * lpTokenAmount) / totalSupply);
        ethAmount = uint96((uint256(pool.ethReserve) * lpTokenAmount) / totalSupply);

        // Check minimum amounts
        require(tokenAmount >= minTokenAmount, "Insufficient token output");
        require(ethAmount >= minEthAmount, "Insufficient ETH output");

        // Update state before external calls
        pool.tokenReserve -= tokenAmount;
        pool.ethReserve -= ethAmount;
        pool.lastUpdateTime = uint32(block.timestamp);

        // Burn LP tokens first
        _burnLPTokens(pool.lpToken, msg.sender, lpTokenAmount);

        // Transfer assets last
        require(ERC20(token).transfer(msg.sender, tokenAmount), "Token transfer failed");
        payable(msg.sender).transfer(ethAmount);

        emit LiquidityRemoved(
            token,
            msg.sender,
            tokenAmount,
            ethAmount,
            lpTokenAmount
        );
    }

    /// @notice Swaps tokens using the pool
    function swap(
        address tokenIn,
        address tokenOut,
        SwapParams calldata params
    ) external payable virtual 
      nonReentrant 
      whenNotPaused 
      flashLoanProtection(msg.sender)
      rateLimit(msg.sender, params.amountIn)
    returns (uint96 amountOut) {
        require(block.timestamp <= params.deadline, "Transaction expired");
        require(tokenIn != tokenOut, "Same token");
        require(params.amountIn > 0, "Invalid amount");

        bool isEthIn = tokenIn == address(0);
        bool isEthOut = tokenOut == address(0);
        require(isEthIn != isEthOut, "Invalid pair");

        address token = isEthIn ? tokenOut : tokenIn;
        PoolInfo storage pool = _pools[token];
        require(pool.status == 1, "Pool inactive");

        // Calculate output amount first
        amountOut = _calculateOutputAmount(pool, params.amountIn, isEthIn);
        require(amountOut >= params.minAmountOut, "Insufficient output amount");

        // Check price impact
        uint256 priceImpact = _calculatePriceImpact(pool, params.amountIn, isEthIn);
        require(priceImpact <= MAX_PRICE_IMPACT, "Price impact too high");

        // Update state before external calls
        if (isEthIn) {
            require(msg.value == params.amountIn, "Invalid ETH");
            pool.ethReserve += params.amountIn;
            pool.tokenReserve -= amountOut;
        } else {
            require(msg.value == 0, "ETH not needed");
            pool.tokenReserve += params.amountIn;
            pool.ethReserve -= amountOut;
        }
        
        pool.lastUpdateTime = uint32(block.timestamp);

        // External calls after state updates
        if (isEthIn) {
            require(ERC20(token).transfer(msg.sender, amountOut), "Transfer failed");
        } else {
            require(ERC20(token).transferFrom(msg.sender, address(this), params.amountIn), "Transfer failed");
            payable(msg.sender).transfer(amountOut);
        }

        emit Swap(msg.sender, tokenIn, tokenOut, params.amountIn, amountOut);
    }

    /// @notice Gets the current reserves for a pool
    function getReserves(address token) external view returns (
        uint96 tokenReserve,
        uint96 ethReserve
    ) {
        PoolInfo storage pool = _pools[token];
        return (uint96(pool.tokenReserve), uint96(pool.ethReserve));
    }

    /// @notice Gets pool information
    function getPoolInfo(address token) external view returns (PoolInfo memory) {
        return _pools[token];
    }

    /// @notice Checks if a pool exists for a token
    function poolExists(address token) external view returns (bool) {
        return _pools[token].token != address(0);
    }

    /// @notice Calculates the output amount for a swap
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        bool isEthIn = tokenIn == address(0);
        bool isEthOut = tokenOut == address(0);
        require(isEthIn != isEthOut, "Invalid pair");

        address token = isEthIn ? tokenOut : tokenIn;
        PoolInfo storage pool = _pools[token];
        require(pool.status == 1, "Pool inactive");

        return _calculateOutputAmount(pool, uint96(amountIn), isEthIn);
    }

    function updatePoolStatus(address token, uint8 status) external {
        require(msg.sender == owner, "Not owner");
        _pools[token].status = status;
        emit PoolStatusUpdated(token, status);
    }

    function getOptimalSwapAmount(
        address tokenIn,
        uint96 amountIn,
        uint96 reserveIn,
        uint96 reserveOut
    ) external view returns (uint96 amountOut) {
        uint256 amountInWithFee = uint256(amountIn) * (1000 - uint256(_pools[tokenIn].fee));
        uint256 numerator = amountInWithFee * uint256(reserveOut);
        uint256 denominator = (uint256(reserveIn) * 1000) + amountInWithFee;
        return uint96(numerator / denominator);
    }

    function emergencyStop() external onlyOwner {
        _paused = true;
        emit EmergencyStop(msg.sender);
    }

    function emergencyResume() external onlyOwner {
        _paused = false;
        emit EmergencyResume(msg.sender);
    }

    // Internal functions
    function _createLPToken(address token) internal virtual returns (address);
    
    function _mintLPTokens(address lpToken, address to, uint96 amount) internal virtual;
    
    function _burnLPTokens(address lpToken, address from, uint96 amount) internal virtual;

    function _calculateOptimalAmounts(
        PoolInfo storage pool,
        uint96 tokenAmount,
        uint96 ethAmount
    ) internal view virtual returns (uint96 optimalTokenAmount, uint96 optimalEthAmount);

    function _calculateLPTokens(
        PoolInfo storage pool,
        uint96 tokenAmount,
        uint96 ethAmount
    ) internal view virtual returns (uint96);

    function _calculateOutputAmount(
        PoolInfo storage pool,
        uint96 amountIn,
        bool ethToToken
    ) internal view virtual returns (uint96);

    function _calculatePriceImpact(
        PoolInfo storage pool,
        uint256 amountIn,
        bool isEthIn
    ) internal view returns (uint256) {
        uint256 reserveIn = isEthIn ? pool.ethReserve : pool.tokenReserve;
        uint256 reserveOut = isEthIn ? pool.tokenReserve : pool.ethReserve;
        
        uint256 amountWithFee = amountIn * (10000 - pool.fee);
        uint256 numerator = amountWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountWithFee;
        uint256 amountOut = numerator / denominator;
        
        uint256 priceImpact = (amountOut * 10000) / (amountIn * reserveOut / reserveIn);
        return 10000 - priceImpact;
    }

    receive() external payable {
        require(msg.sender == address(0), "Only ETH");
    }
} 