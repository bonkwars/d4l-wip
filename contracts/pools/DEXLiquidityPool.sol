// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/uniswap/IUniswapV3Core.sol";
import "../interfaces/uniswap/INonfungiblePositionManager.sol";
import "../interfaces/uniswap/ISwapRouter.sol";
import "../interfaces/ITokenomics.sol";


/**
 * @title DEXLiquidityPool
 * @notice Manages DEX liquidity with Uniswap V3, anti-rug pull, and anti-bot protections
 */
contract DEXLiquidityPool is Ownable, ReentrancyGuard, Pausable {
    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_LIQUIDITY_LOCK = 180 days;
    uint256 public constant LIQUIDITY_RELEASE_DELAY = 7 days;
    uint24 public constant POOL_FEE = 3000; // 0.3%
    int24 public constant TICK_SPACING = 60;

    // Anti-bot settings
    uint256 public constant MAX_WALLET_PERCENT = 100; // 1% max wallet size
    uint256 public constant MAX_TX_PERCENT = 50;      // 0.5% max transaction
    uint256 public constant COOLDOWN_PERIOD = 60;     // 60 seconds between trades
    uint256 public constant LAUNCH_PERIOD = 1 hours;  // Special launch restrictions

    // State variables
    IUniswapV3Factory public immutable factory;
    INonfungiblePositionManager public immutable positionManager;
    ISwapRouter public immutable router;
    IERC20 public immutable rewardToken;
    address public immutable WETH;
    address public immutable distributor;
    
    mapping(uint256 => uint256) public positionUnlockTime;  // NFT ID => unlock time
    mapping(address => uint256) public lastTradeTime;       // Address => last trade timestamp
    mapping(address => bool) public isWhitelisted;          // Addresses exempt from restrictions
    
    uint256[] public activePositions;                      // Array of NFT position IDs
    uint256 public launchTime;                             // Timestamp of pool launch
    uint256 public totalLiquidity;
    bool public tradingEnabled;
    bool public antiBotEnabled;

    // Anti-rug pull locks
    uint256 public liquidityLockPeriod;
    uint256 public lastLiquidityLock;
    address public immutable timelock;                     // Timelock contract for governance
    uint256 public constant TIMELOCK_DELAY = 48 hours;    // Minimum delay for timelock actions

    // Events
    event LiquidityAdded(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event PositionCreated(uint256 indexed tokenId, int24 tickLower, int24 tickUpper);
    event TradingStateUpdated(bool enabled);
    event AntiBotStateUpdated(bool enabled);
    event WhitelistUpdated(address indexed account, bool status);
    event LiquidityLockUpdated(uint256 newPeriod);
    event EmergencyWithdrawn(address indexed token, uint256 amount, address recipient);

    // Modifiers
    modifier onlyDistributor() {
        require(msg.sender == distributor, "Only distributor");
        _;
    }

    modifier onlyTimelock() {
        require(msg.sender == timelock, "Only timelock");
        _;
    }

    modifier tradingAllowed() {
        require(tradingEnabled, "Trading not enabled");
        if (antiBotEnabled) {
            require(
                isWhitelisted[msg.sender] ||
                block.timestamp >= launchTime + LAUNCH_PERIOD,
                "Launch protection active"
            );
            require(
                block.timestamp >= lastTradeTime[msg.sender] + COOLDOWN_PERIOD,
                "Cooldown active"
            );
        }
        _;
    }

    constructor(
        address _factory,
        address _positionManager,
        address _router,
        address _rewardToken,
        address _distributor,
        address _timelock
    ) Ownable(msg.sender) {
        require(_factory != address(0), "Invalid factory");
        require(_positionManager != address(0), "Invalid position manager");
        require(_router != address(0), "Invalid router");
        require(_rewardToken != address(0), "Invalid token");
        require(_distributor != address(0), "Invalid distributor");
        require(_timelock != address(0), "Invalid timelock");

        factory = IUniswapV3Factory(_factory);
        positionManager = INonfungiblePositionManager(_positionManager);
        router = ISwapRouter(_router);
        rewardToken = IERC20(_rewardToken);
        WETH = ISwapRouter(_router).WETH9();
        distributor = _distributor;
        timelock = _timelock;

        liquidityLockPeriod = MIN_LIQUIDITY_LOCK;
        antiBotEnabled = true;
    }

    /**
     * @notice Creates a new Uniswap V3 position
     */
    function createPosition(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external onlyOwner returns (uint256 tokenId) {
        require(
            tickLower < tickUpper &&
            tickLower % TICK_SPACING == 0 &&
            tickUpper % TICK_SPACING == 0,
            "Invalid ticks"
        );

        // Transfer tokens to this contract
        if (amount0Desired > 0) {
            require(rewardToken.transferFrom(msg.sender, address(this), amount0Desired), "Transfer failed");
        }
        if (amount1Desired > 0) {
            require(IERC20(WETH).transferFrom(msg.sender, address(this), amount1Desired), "Transfer failed");
        }

        // Approve position manager
        rewardToken.approve(address(positionManager), amount0Desired);
        IERC20(WETH).approve(address(positionManager), amount1Desired);

        // Create position
        (tokenId,,,) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(rewardToken),
                token1: WETH,
                fee: POOL_FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        // Lock position
        positionUnlockTime[tokenId] = block.timestamp + liquidityLockPeriod;
        activePositions.push(tokenId);
        lastLiquidityLock = block.timestamp;

        emit PositionCreated(tokenId, tickLower, tickUpper);
    }

    /**
     * @notice Increases liquidity in an existing position
     */
    function increaseLiquidity(
        uint256 tokenId,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external onlyOwner {
        require(positionUnlockTime[tokenId] > 0, "Invalid position");

        // Transfer tokens
        if (amount0Desired > 0) {
            require(rewardToken.transferFrom(msg.sender, address(this), amount0Desired), "Transfer failed");
        }
        if (amount1Desired > 0) {
            require(IERC20(WETH).transferFrom(msg.sender, address(this), amount1Desired), "Transfer failed");
        }

        // Approve position manager
        rewardToken.approve(address(positionManager), amount0Desired);
        IERC20(WETH).approve(address(positionManager), amount1Desired);

        // Increase liquidity
        positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        // Update lock period
        positionUnlockTime[tokenId] = block.timestamp + liquidityLockPeriod;
        lastLiquidityLock = block.timestamp;

        emit LiquidityAdded(tokenId, amount0Desired, amount1Desired);
    }

    /**
     * @notice Removes liquidity from a position (only through timelock)
     */
    function removeLiquidity(
        uint256 tokenId,
        uint128 liquidityAmount
    ) external onlyTimelock {
        require(
            block.timestamp >= positionUnlockTime[tokenId],
            "Position locked"
        );

        // Remove liquidity
        (uint256 amount0, uint256 amount1) = positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidityAmount,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        // Collect fees
        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        emit LiquidityRemoved(tokenId, amount0, amount1);
    }

    /**
     * @notice Updates trading restrictions
     */
    function setTradingEnabled(bool enabled) external onlyTimelock {
        if (enabled && !tradingEnabled) {
            launchTime = block.timestamp;
        }
        tradingEnabled = enabled;
        emit TradingStateUpdated(enabled);
    }

    /**
     * @notice Updates anti-bot protection status
     */
    function setAntiBotEnabled(bool enabled) external onlyTimelock {
        antiBotEnabled = enabled;
        emit AntiBotStateUpdated(enabled);
    }

    /**
     * @notice Updates whitelist status
     */
    function updateWhitelist(address account, bool status) external onlyOwner {
        isWhitelisted[account] = status;
        emit WhitelistUpdated(account, status);
    }

    /**
     * @notice Updates liquidity lock period (only through timelock)
     */
    function updateLiquidityLock(uint256 newPeriod) external onlyTimelock {
        require(
            newPeriod >= MIN_LIQUIDITY_LOCK,
            "Lock too short"
        );
        require(
            block.timestamp >= lastLiquidityLock + LIQUIDITY_RELEASE_DELAY,
            "Recent lock"
        );
        liquidityLockPeriod = newPeriod;
        emit LiquidityLockUpdated(newPeriod);
    }

    /**
     * @notice Validates transaction against anti-bot rules
     */
    function validateTransaction(
        address sender,
        uint256 amount
    ) internal view {
        if (!isWhitelisted[sender]) {
            uint256 maxWalletAmount = (rewardToken.totalSupply() * MAX_WALLET_PERCENT) / BASIS_POINTS;
            uint256 maxTxAmount = (rewardToken.totalSupply() * MAX_TX_PERCENT) / BASIS_POINTS;
            
            require(amount <= maxTxAmount, "TX size exceeds limit");
            require(
                rewardToken.balanceOf(sender) + amount <= maxWalletAmount,
                "Wallet size exceeds limit"
            );
        }
    }

    /**
     * @notice Distributes new funds from the automated distributor
     */
    function distributeRewards() external payable onlyDistributor nonReentrant whenNotPaused {
        require(msg.value > 0, "Zero value");
        
        // Add liquidity across active positions
        for (uint256 i = 0; i < activePositions.length; i++) {
            uint256 tokenId = activePositions[i];
            uint256 amount = msg.value / activePositions.length;
            
            // Add liquidity to position using positionManager
            positionManager.increaseLiquidity(
                INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: 0,
                    amount1Desired: amount,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );
        }
    }

    /**
     * @notice Emergency withdrawal of stuck funds (through timelock)
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyTimelock {
        require(recipient != address(0), "Invalid recipient");
        
        if (token == address(0)) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            require(IERC20(token).transfer(recipient, amount), "Token transfer failed");
        }

        emit EmergencyWithdrawn(token, amount, recipient);
    }

    /**
     * @notice Pauses all non-essential functions
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses all functions
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {
        require(
            msg.sender == distributor ||
            msg.sender == address(router) ||
            msg.sender == address(positionManager),
            "Invalid sender"
        );
    }
} 