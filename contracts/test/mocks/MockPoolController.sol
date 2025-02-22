// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/IPoolController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockPoolController is IPoolController {
    mapping(address => PoolConfig) private _pools;
    mapping(address => PoolInfo) private _poolInfo;
    mapping(address => address[]) private _userPools;
    address[] private _activePools;
    bool private _paused;

   

 function initializePool(
    address token,
    PoolConfig memory config,
    address liquidityProvider
) external payable override {
    require(_pools[token].poolAddress == address(0), "Pool exists");
    require(config.initialLiquidity > 0, "Invalid initial liquidity");
    require(config.minLiquidity > 0, "Invalid min liquidity");
    require(config.maxLiquidity > config.minLiquidity, "Invalid max liquidity");
    require(config.lockDuration > 0, "Invalid lock duration");
    
    // Store pool configuration
    _pools[token] = config;
    _poolInfo[token] = PoolInfo({
        poolAddress: address(this),
        tokenReserve: config.initialLiquidity,
        ethReserve: msg.value >= config.initialLiquidity ? config.initialLiquidity : 0,
        totalLiquidity: config.initialLiquidity * 2,  // Total liquidity is double the initial amount
        tradingEnabled: false,
        lockEnd: block.timestamp + config.lockDuration
    });
    
    if (config.initialLiquidity > 0 && msg.value >= config.initialLiquidity) {
        // If the caller (msg.sender) is the same as liquidityProvider, do a direct transfer
        if (msg.sender == liquidityProvider) {
            require(
                IERC20(token).transfer(address(this), config.initialLiquidity),
                "Direct transfer failed"
            );
        } else {
            require(
                IERC20(token).transferFrom(liquidityProvider, address(this), config.initialLiquidity),
                "Token transfer failed: insufficient allowance"
            );
        }
        if (msg.value > config.initialLiquidity) {
            payable(msg.sender).transfer(msg.value - config.initialLiquidity);
        }
    }
    
    emit PoolCreated(token, address(this), config);
}



    function addLiquidity(address token, uint256 tokenAmount) external payable override {
        PoolConfig memory config = _pools[token];
        PoolInfo storage info = _poolInfo[token];
        
        require(tokenAmount >= config.minLiquidity, "Below min liquidity");
        require(info.tokenReserve + tokenAmount <= config.maxLiquidity, "Exceeds max liquidity");
        require(info.ethReserve + msg.value <= config.maxLiquidity, "Exceeds max liquidity");
        
        // Transfer tokens from the sender to this contract
        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
        
        // Update reserves
        info.tokenReserve = info.tokenReserve + tokenAmount;
        info.ethReserve = info.ethReserve + msg.value;
        info.totalLiquidity = info.tokenReserve * 2;  // Total liquidity is double the token reserve
        
        emit LiquidityAdded(token, tokenAmount, msg.value);
    }

    function removeLiquidity(address token, uint256 liquidity) external override {
        PoolInfo storage info = _poolInfo[token];
        
        // Calculate amounts based on liquidity share
        uint256 tokenAmount = (info.tokenReserve * liquidity) / info.totalLiquidity;
        uint256 ethAmount = (info.ethReserve * liquidity) / info.totalLiquidity;
        
        // Update reserves
        info.tokenReserve = info.tokenReserve - tokenAmount;
        info.ethReserve = info.ethReserve - ethAmount;
        info.totalLiquidity = info.tokenReserve * 2;  // Total liquidity is double the token reserve
        
        // Transfer tokens back to the sender
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
