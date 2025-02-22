// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "../../interfaces/dex/IDex.sol";
import "../../interfaces/dex/IDexRouter.sol";
import "../../interfaces/IContractRegistry.sol";

/**
 * @title D4LDex
 * @notice Main DEX contract that coordinates liquidity pools and trading
 */
contract D4LDex is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IDex 
{
    // State variables
    IContractRegistry public registry;
    address public WETH;
    
    // Protocol fees (in basis points)
    uint16 public swapFee;      // 0.3% = 30
    uint16 public protocolFee;  // 0.1% = 10
    uint16 public lpFee;        // 0.2% = 20

    // Fee collector
    address public feeCollector;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _registry,
        address _weth,
        address _feeCollector
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_registry != address(0), "Invalid registry");
        require(_weth != address(0), "Invalid WETH");
        require(_feeCollector != address(0), "Invalid fee collector");

        registry = IContractRegistry(_registry);
        WETH = _weth;
        feeCollector = _feeCollector;

        // Set default fees
        swapFee = 30;      // 0.3%
        protocolFee = 10;  // 0.1%
        lpFee = 20;        // 0.2%
    }

    // External functions
    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external override nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(block.timestamp <= deadline, "Expired");
        require(tokenIn != tokenOut, "Same token");
        
        // Get router from registry
        address router = registry.getContractAddressByName("DEX_ROUTER");
        require(router != address(0), "Router not found");

        // Execute swap through router
        amountOut = IDexRouter(router).executeSwap(
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            to,
            calculateFees(amountIn)
        );

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, getFees(amountIn));
        return amountOut;
    }

    function swapExactETHForTokens(
        address tokenOut,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external payable override nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(block.timestamp <= deadline, "Expired");
        require(msg.value > 0, "Zero ETH");

        // Get router
        address router = registry.getContractAddressByName("DEX_ROUTER");
        require(router != address(0), "Router not found");

        // Execute swap
        amountOut = IDexRouter(router).executeETHSwap{value: msg.value}(
            tokenOut,
            minAmountOut,
            to,
            calculateFees(msg.value)
        );

        emit Swap(msg.sender, WETH, tokenOut, msg.value, amountOut, getFees(msg.value));
        return amountOut;
    }

    function swapExactTokensForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address payable to,
        uint256 deadline
    ) external override nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(block.timestamp <= deadline, "Expired");
        require(amountIn > 0, "Zero amount");

        // Get router
        address router = registry.getContractAddressByName("DEX_ROUTER");
        require(router != address(0), "Router not found");

        // Execute swap
        amountOut = IDexRouter(router).executeTokenToETHSwap(
            tokenIn,
            amountIn,
            minAmountOut,
            to,
            calculateFees(amountIn)
        );

        emit Swap(msg.sender, tokenIn, WETH, amountIn, amountOut, getFees(amountIn));
        return amountOut;
    }

    // View functions
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view override returns (uint256) {
        address router = registry.getContractAddressByName("DEX_ROUTER");
        require(router != address(0), "Router not found");
        return IDexRouter(router).getAmountOut(tokenIn, tokenOut, amountIn);
    }

    function getPriceImpact(
        address token,
        uint256 amount,
        bool isBuy
    ) external view override returns (uint256) {
        address router = registry.getContractAddressByName("DEX_ROUTER");
        require(router != address(0), "Router not found");
        return IDexRouter(router).getPriceImpact(token, amount, isBuy);
    }

    // Admin functions
    function setFees(
        uint16 _swapFee,
        uint16 _protocolFee,
        uint16 _lpFee
    ) external onlyOwner {
        require(_swapFee == _protocolFee + _lpFee, "Invalid fee split");
        require(_swapFee <= 100, "Fee too high"); // Max 1%
        
        swapFee = _swapFee;
        protocolFee = _protocolFee;
        lpFee = _lpFee;
        
        emit FeeUpdated(swapFee, protocolFee, lpFee);
    }

    function setFeeCollector(address _feeCollector) external onlyOwner {
        require(_feeCollector != address(0), "Invalid address");
        feeCollector = _feeCollector;
        emit FeeCollectorUpdated(_feeCollector);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Internal functions
    function calculateFees(uint256 amount) internal view returns (Fees memory) {
        return Fees({
            total: (amount * swapFee) / 10000,
            protocol: (amount * protocolFee) / 10000,
            lp: (amount * lpFee) / 10000
        });
    }

    function getFees(uint256 amount) internal view returns (uint256) {
        return (amount * swapFee) / 10000;
    }

    receive() external payable {
        require(msg.sender == WETH, "Only WETH");
    }
} 