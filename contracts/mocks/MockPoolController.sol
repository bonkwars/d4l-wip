// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IPoolController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockPoolController is IPoolController, ReentrancyGuard, Ownable {
    mapping(address => PoolConfig) private _pools;
    mapping(address => PoolInfo) private _poolInfo;
    mapping(address => address[]) private _userPools;
    address[] private _activePools;
    bool private _paused;

    constructor() Ownable(msg.sender) {}

    modifier whenNotPaused() {
        require(!_paused, "Contract is paused");
        _;
    }

    function initializePool(address token, PoolConfig memory config, address liquidityProvider) external payable override {
        require(config.initialLiquidity > 0, "Invalid initial liquidity");
        require(config.minLiquidity > 0, "Invalid min liquidity");
        require(config.maxLiquidity > config.minLiquidity, "Invalid max liquidity");
        require(config.lockDuration > 0, "Invalid lock duration");
        require(msg.value >= config.initialLiquidity, "Insufficient ETH sent");
        
        // Store pool configuration
        _pools[token] = config;
        _poolInfo[token] = PoolInfo({
            poolAddress: address(this),
            tokenReserve: config.initialLiquidity,
            ethReserve: msg.value >= config.initialLiquidity ? config.initialLiquidity : 0,
            totalLiquidity: config.initialLiquidity * 2,
            tradingEnabled: false,
            lockEnd: block.timestamp + config.lockDuration
        });
        
        // Add to active pools
        _activePools.push(token);
        
        // Refund excess ETH if any
        if (msg.value > config.initialLiquidity) {
            payable(msg.sender).transfer(msg.value - config.initialLiquidity);
        }
        
        emit PoolCreated(token, address(this), config);
    }

    function addLiquidity(address token, uint256 tokenAmount) external payable override whenNotPaused nonReentrant {
        require(tokenAmount > 0, "Token amount must be greater than 0");
        require(msg.value > 0, "ETH amount must be greater than 0");
        
        PoolConfig memory config = _pools[token];
        PoolInfo storage info = _poolInfo[token];
        
        // For initial liquidity, require equal token and ETH amounts
        if (info.totalLiquidity == 0) {
            require(tokenAmount == msg.value, "Unequal initial liquidity");
            require(tokenAmount >= config.minLiquidity, "Below min liquidity");
            
            info.tokenReserve = tokenAmount;
            info.ethReserve = msg.value;
            info.totalLiquidity = tokenAmount + msg.value;
        } else {
            // Calculate new reserves
            uint256 newTokenReserve = info.tokenReserve + tokenAmount;
            uint256 newEthReserve = info.ethReserve + msg.value;
            uint256 newTotalLiquidity = newTokenReserve + newEthReserve;
            
            // Check liquidity limits
            require(newTotalLiquidity <= config.maxLiquidity, "Exceeds max liquidity");
            
            // Update reserves and total liquidity
            info.tokenReserve = newTokenReserve;
            info.ethReserve = newEthReserve;
            info.totalLiquidity = newTotalLiquidity;
        }
        
        emit LiquidityAdded(token, tokenAmount, msg.value);
    }

    function removeLiquidity(address token, uint256 liquidity) external override whenNotPaused nonReentrant {
        require(liquidity > 0, "Liquidity amount must be greater than 0");
        
        PoolInfo storage info = _poolInfo[token];
        PoolConfig memory config = _pools[token];
        
        require(block.timestamp >= info.lockEnd, "Liquidity locked");
        
        // Calculate amounts based on liquidity share
        uint256 tokenAmount = (info.tokenReserve * liquidity) / info.totalLiquidity;
        uint256 ethAmount = (info.ethReserve * liquidity) / info.totalLiquidity;
        
        // Calculate remaining liquidity
        uint256 remainingLiquidity = info.totalLiquidity - liquidity;
        
        // Check minimum liquidity requirement
        require(remainingLiquidity >= config.minLiquidity || remainingLiquidity == 0, 
                "Below min liquidity");
        
        // Check balances
        require(IERC20(token).balanceOf(address(this)) >= tokenAmount, "Insufficient token balance");
        require(address(this).balance >= ethAmount, "Insufficient ETH balance");
        
        // Update state before external calls
        info.tokenReserve = info.tokenReserve - tokenAmount;
        info.ethReserve = info.ethReserve - ethAmount;
        info.totalLiquidity = remainingLiquidity;
        
        // Transfer tokens and ETH
        IERC20(token).transfer(msg.sender, tokenAmount);
        payable(msg.sender).transfer(ethAmount);
        
        emit LiquidityRemoved(token, tokenAmount, ethAmount);
    }

    function enableTrading(address token) external override {
        _poolInfo[token].tradingEnabled = true;
        emit TradingEnabled(token);
    }

    function disableTrading(address token) external override {
        _poolInfo[token].tradingEnabled = false;
        emit TradingDisabled(token);
    }

    function getPoolInfo(address token) external view override returns (
        address poolAddress,
        uint256 tokenReserve,
        uint256 ethReserve,
        uint256 totalLiquidity,
        bool tradingEnabled,
        uint256 lockEnd
    ) {
        PoolInfo memory info = _poolInfo[token];
        return (
            info.poolAddress,
            info.tokenReserve,
            info.ethReserve,
            info.totalLiquidity,
            info.tradingEnabled,
            info.lockEnd
        );
    }

    function createPool(
        address token,
        PoolConfig memory config,
        address owner
    ) external override returns (address) {
        _pools[token] = config;
        _userPools[owner].push(token);
        _activePools.push(token);
        emit PoolCreated(token, address(this), config);
        return address(this);
    }

    function getActivePools() external view override returns (address[] memory) {
        return _activePools;
    }

    function getUserPools(address user) external view override returns (address[] memory) {
        return _userPools[user];
    }

    function pauseAll() external override {
        _paused = true;
    }

    function unpauseAll() external override {
        _paused = false;
    }

    function setDependencies(
        address factory,
        address registry,
        address curve
    ) external override {
        // No-op for testing
    }

    receive() external payable {}
} 