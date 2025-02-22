// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IContractRegistry.sol";
import "../interfaces/ILiquidityPool.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IHydraCurve.sol";

contract LiquidityModule is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable 
{
    // State variables
    IContractRegistry public registry;
    address public WETH;

    // Constants
    uint256 public constant MIN_LOCK_DURATION = 7 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;
    uint256 public constant DEFAULT_SWAP_FEE = 30; // 0.3%
    uint256 public constant MIN_INITIAL_LIQUIDITY = 1000;

    // Events
    event PoolInitialized(
        address indexed token,
        address indexed creator,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 lockDuration
    );

    event LiquidityProvided(
        address indexed token,
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount
    );

    event LiquidityWithdrawn(
        address indexed token,
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount
    );

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
    function initializePool(
        address token,
        ILiquidityPool.PoolInfo calldata params,
        address creator,
        uint256 initialEthAmount
    ) external payable nonReentrant whenNotPaused {
        require(msg.value == initialEthAmount, "Invalid ETH amount");
        require(params.tokenReserve >= MIN_INITIAL_LIQUIDITY, "Insufficient initial liquidity");
        require(params.lockDuration >= MIN_LOCK_DURATION && params.lockDuration <= MAX_LOCK_DURATION, "Invalid lock duration");

        // Get pool contract
        ILiquidityPool pool = ILiquidityPool(registry.getContractAddressByName("LIQUIDITY_POOL"));

        // Transfer initial tokens from creator
        IERC20(token).transferFrom(creator, address(this), params.tokenReserve);
        IERC20(token).approve(address(pool), params.tokenReserve);

        // Create pool
        pool.createPool{value: initialEthAmount}(
            token,
            params.tokenReserve,
            initialEthAmount,
            params.lockDuration,
            params.fee > 0 ? params.fee : DEFAULT_SWAP_FEE,
            params.status > 0 // Auto-liquidity if status is set
        );

        emit PoolInitialized(
            token,
            creator,
            params.tokenReserve,
            initialEthAmount,
            params.lockDuration
        );
    }

    function provideLiquidity(
        address token,
        uint256 tokenAmount,
        uint256 minEthAmount
    ) external payable nonReentrant whenNotPaused {
        ILiquidityPool pool = ILiquidityPool(registry.getContractAddressByName("LIQUIDITY_POOL"));

        // Transfer tokens
        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
        IERC20(token).approve(address(pool), tokenAmount);

        // Add liquidity
        uint256 liquidity = pool.addLiquidity{value: msg.value}(
            token,
            tokenAmount,
            minEthAmount
        );

        require(liquidity > 0, "No liquidity added");

        emit LiquidityProvided(
            token,
            msg.sender,
            tokenAmount,
            msg.value
        );
    }

    function withdrawLiquidity(
        address token,
        uint256 liquidity,
        uint256 minTokenAmount,
        uint256 minEthAmount
    ) external nonReentrant {
        ILiquidityPool pool = ILiquidityPool(registry.getContractAddressByName("LIQUIDITY_POOL"));

        // Remove liquidity
        (uint256 tokenAmount, uint256 ethAmount) = pool.removeLiquidity(
            token,
            liquidity,
            minTokenAmount,
            minEthAmount
        );

        // Transfer assets to user
        IERC20(token).transfer(msg.sender, tokenAmount);
        payable(msg.sender).transfer(ethAmount);

        emit LiquidityWithdrawn(
            token,
            msg.sender,
            tokenAmount,
            ethAmount
        );
    }

    // View functions
    function getPoolInfo(address token) external view returns (ILiquidityPool.PoolInfo memory) {
        ILiquidityPool pool = ILiquidityPool(registry.getContractAddressByName("LIQUIDITY_POOL"));
        return pool.getPoolInfo(token);
    }

    function checkLiquidityLimits(
        address token,
        uint256 amount
    ) external view returns (
        uint256 minTokenAmount,
        uint256 maxTokenAmount,
        uint256 minEthAmount,
        uint256 maxEthAmount
    ) {
        ILiquidityPool pool = ILiquidityPool(registry.getContractAddressByName("LIQUIDITY_POOL"));
        IHydraCurve curve = IHydraCurve(registry.getContractAddressByName("HYDRA_CURVE"));
        IPriceOracle oracle = IPriceOracle(registry.getContractAddressByName("PRICE_ORACLE"));

        // Get pool info
        (uint256 tokenReserve, uint256 ethReserve,,,,, bool autoLiquidity) = pool.getPool(token);

        if (tokenReserve == 0 || ethReserve == 0) {
            // For new pools, use price oracle
            uint256 tokenPrice = oracle.getPrice(token);
            minTokenAmount = MIN_INITIAL_LIQUIDITY;
            maxTokenAmount = curve.calculatePrice(token, ethReserve * 2);
            minEthAmount = (minTokenAmount * tokenPrice) / 1e18;
            maxEthAmount = (maxTokenAmount * tokenPrice) / 1e18;
        } else {
            // For existing pools, maintain ratio
            minTokenAmount = (amount * tokenReserve) / ethReserve;
            maxTokenAmount = minTokenAmount * 2;
            minEthAmount = amount;
            maxEthAmount = amount * 2;
        }
    }

    // Admin functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Fallback functions
    receive() external payable {}
    fallback() external payable {}
} 