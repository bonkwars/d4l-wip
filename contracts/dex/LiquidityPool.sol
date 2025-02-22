// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IContractRegistry.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IHydraCurve.sol";

contract LiquidityPool is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable 
{
    struct Pool {
        uint256 tokenReserve;
        uint256 ethReserve;
        uint256 totalLiquidity;
        uint256 lastUpdateTime;
        uint256 lockDuration;
        uint256 swapFee;
        bool autoLiquidity;
    }

    struct LockedLiquidity {
        uint256 amount;
        uint256 unlockTime;
    }

    // State variables
    IContractRegistry public registry;
    address public WETH;
    mapping(address => Pool) public pools;
    mapping(address => mapping(address => uint256)) public liquidityBalance;
    mapping(address => mapping(address => LockedLiquidity)) public lockedLiquidity;

    // Constants
    uint256 public constant MIN_LIQUIDITY = 1000;
    uint256 public constant MAX_SWAP_FEE = 1000; // 10%
    uint256 public constant FEE_DENOMINATOR = 10000;

    // Events
    event LiquidityAdded(
        address indexed token,
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed token,
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event PoolCreated(
        address indexed token,
        uint256 initialLiquidity,
        uint256 lockDuration,
        uint256 swapFee
    );

    event SwapFeeUpdated(address indexed token, uint256 newFee);
    event AutoLiquidityUpdated(address indexed token, bool enabled);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _registry,
        address _weth
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_registry != address(0), "Invalid registry");
        require(_weth != address(0), "Invalid WETH");

        registry = IContractRegistry(_registry);
        WETH = _weth;
    }

    // External functions
    function createPool(
        address token,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 lockDuration,
        uint256 swapFee,
        bool autoLiquidity
    ) external payable nonReentrant whenNotPaused {
        require(pools[token].totalLiquidity == 0, "Pool exists");
        require(tokenAmount > 0 && ethAmount > 0, "Zero amount");
        require(msg.value == ethAmount, "Invalid ETH");
        require(swapFee <= MAX_SWAP_FEE, "Fee too high");

        // Transfer tokens
        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);

        // Calculate initial liquidity
        uint256 liquidity = _sqrt(tokenAmount * ethAmount);
        require(liquidity >= MIN_LIQUIDITY, "Insufficient liquidity");

        // Initialize pool
        pools[token] = Pool({
            tokenReserve: tokenAmount,
            ethReserve: ethAmount,
            totalLiquidity: liquidity,
            lastUpdateTime: block.timestamp,
            lockDuration: lockDuration,
            swapFee: swapFee,
            autoLiquidity: autoLiquidity
        });

        // Assign liquidity tokens
        liquidityBalance[token][msg.sender] = liquidity;
        if (lockDuration > 0) {
            lockedLiquidity[token][msg.sender] = LockedLiquidity({
                amount: liquidity,
                unlockTime: block.timestamp + lockDuration
            });
        }

        emit PoolCreated(token, liquidity, lockDuration, swapFee);
        emit LiquidityAdded(token, msg.sender, tokenAmount, ethAmount, liquidity);
    }

    function addLiquidity(
        address token,
        uint256 minTokenAmount,
        uint256 minEthAmount
    ) external payable nonReentrant whenNotPaused returns (uint256 liquidity) {
        Pool storage pool = pools[token];
        require(pool.totalLiquidity > 0, "Pool not found");

        // Calculate amounts
        uint256 ethAmount = msg.value;
        uint256 tokenAmount = (ethAmount * pool.tokenReserve) / pool.ethReserve;

        require(tokenAmount >= minTokenAmount, "Insufficient token amount");
        require(ethAmount >= minEthAmount, "Insufficient ETH amount");

        // Transfer tokens
        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);

        // Calculate liquidity
        liquidity = (ethAmount * pool.totalLiquidity) / pool.ethReserve;
        require(liquidity > 0, "Zero liquidity");

        // Update pool
        pool.tokenReserve += tokenAmount;
        pool.ethReserve += ethAmount;
        pool.totalLiquidity += liquidity;
        pool.lastUpdateTime = block.timestamp;

        // Assign liquidity tokens
        liquidityBalance[token][msg.sender] += liquidity;
        if (pool.lockDuration > 0) {
            lockedLiquidity[token][msg.sender] = LockedLiquidity({
                amount: liquidity,
                unlockTime: block.timestamp + pool.lockDuration
            });
        }

        emit LiquidityAdded(token, msg.sender, tokenAmount, ethAmount, liquidity);
    }

    function removeLiquidity(
        address token,
        uint256 liquidity,
        uint256 minTokenAmount,
        uint256 minEthAmount
    ) external nonReentrant returns (uint256 tokenAmount, uint256 ethAmount) {
        Pool storage pool = pools[token];
        require(pool.totalLiquidity > 0, "Pool not found");
        require(liquidityBalance[token][msg.sender] >= liquidity, "Insufficient liquidity");

        // Check lock status
        LockedLiquidity storage locked = lockedLiquidity[token][msg.sender];
        if (locked.amount > 0) {
            require(block.timestamp >= locked.unlockTime, "Liquidity locked");
            require(liquidity <= locked.amount, "Amount exceeds locked");
            locked.amount -= liquidity;
        }

        // Calculate amounts
        tokenAmount = (liquidity * pool.tokenReserve) / pool.totalLiquidity;
        ethAmount = (liquidity * pool.ethReserve) / pool.totalLiquidity;

        require(tokenAmount >= minTokenAmount, "Insufficient token output");
        require(ethAmount >= minEthAmount, "Insufficient ETH output");

        // Update pool
        pool.tokenReserve -= tokenAmount;
        pool.ethReserve -= ethAmount;
        pool.totalLiquidity -= liquidity;
        pool.lastUpdateTime = block.timestamp;
        liquidityBalance[token][msg.sender] -= liquidity;

        // Transfer assets
        IERC20(token).transfer(msg.sender, tokenAmount);
        payable(msg.sender).transfer(ethAmount);

        emit LiquidityRemoved(token, msg.sender, tokenAmount, ethAmount, liquidity);
    }

    // Admin functions
    function setSwapFee(address token, uint256 newFee) external onlyOwner {
        require(newFee <= MAX_SWAP_FEE, "Fee too high");
        pools[token].swapFee = newFee;
        emit SwapFeeUpdated(token, newFee);
    }

    function setAutoLiquidity(address token, bool enabled) external onlyOwner {
        pools[token].autoLiquidity = enabled;
        emit AutoLiquidityUpdated(token, enabled);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // View functions
    function getPool(address token) external view returns (
        uint256 tokenReserve,
        uint256 ethReserve,
        uint256 totalLiquidity,
        uint256 lastUpdateTime,
        uint256 lockDuration,
        uint256 swapFee,
        bool autoLiquidity
    ) {
        Pool memory pool = pools[token];
        return (
            pool.tokenReserve,
            pool.ethReserve,
            pool.totalLiquidity,
            pool.lastUpdateTime,
            pool.lockDuration,
            pool.swapFee,
            pool.autoLiquidity
        );
    }

    // Internal functions
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // Fallback functions
    receive() external payable {}
    fallback() external payable {}
} 