// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IHydraCurve.sol";
import "../interfaces/ITokenomics.sol";
import "../interfaces/IContractRegistry.sol";


contract Degen4LifeDEX is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable 
{
    // State variables
    IContractRegistry public registry;
    address public WETH;
    address public priceOracle;
    address public swapRouter;
    address public feeCollector;

    // Default tokens
    address public constant USDT = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb; // Base mainnet USDT
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base mainnet USDC
    address public constant BASE = 0x4200000000000000000000000000000000000006; // Base token (WETH on Base)

    // Token management
    mapping(address => bool) public acceptedTokens;
    mapping(address => bool) public isD4LToken;

    // Constants
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant FEE_DENOMINATOR = 10000;

    // Fee structure
    uint256 public swapFee; // Default 0.3% = 30
    uint256 public protocolFee; // Default 0.1% = 10
    uint256 public lpFee; // Default 0.2% = 20

    // Events
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    event FeeUpdated(
        uint256 swapFee,
        uint256 protocolFee,
        uint256 lpFee
    );

    event RouterUpdated(address indexed router);
    event PriceOracleUpdated(address indexed oracle);
    event FeeCollectorUpdated(address indexed collector);

    event TokenAccepted(address indexed token, bool status);
    event D4LTokenRegistered(address indexed token, bool status);

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
        
        // Set default fees
        swapFee = 30; // 0.3%
        protocolFee = 10; // 0.1%
        lpFee = 20; // 0.2%

        feeCollector = msg.sender;

        // Accept default tokens
        acceptedTokens[USDT] = true;
        acceptedTokens[USDC] = true;
        acceptedTokens[BASE] = true;
        acceptedTokens[WETH] = true;

        emit TokenAccepted(USDT, true);
        emit TokenAccepted(USDC, true);
        emit TokenAccepted(BASE, true);
        emit TokenAccepted(WETH, true);
    }

    // External functions
    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(deadline >= block.timestamp, "Expired");
        require(tokenIn != tokenOut, "Same tokens");
        require(amountIn > 0, "Zero amount");
        require(isTokenAccepted(tokenIn), "Token not accepted");
        require(isTokenAccepted(tokenOut), "Token not accepted");

        // Transfer tokens from user
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Calculate output amount using HydraCurve
        IHydraCurve curve = IHydraCurve(registry.getContractAddressByName("HYDRA_CURVE"));
        amountOut = curve.calculatePrice(tokenOut, amountIn);

        // Apply fees
        uint256 totalFee = (amountOut * swapFee) / FEE_DENOMINATOR;
        uint256 protocolAmount = (totalFee * protocolFee) / swapFee;
        uint256 lpAmount = (totalFee * lpFee) / swapFee;
        amountOut = amountOut - totalFee;

        require(amountOut >= minAmountOut, "Insufficient output");

        // Handle fees
        if (protocolAmount > 0) {
            IERC20(tokenOut).transfer(feeCollector, protocolAmount);
        }
        if (lpAmount > 0) {
            // Add to liquidity pool (to be implemented)
            IERC20(tokenOut).transfer(address(this), lpAmount);
        }

        // Transfer tokens to recipient
        IERC20(tokenOut).transfer(to, amountOut);

        emit Swap(
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            totalFee
        );
    }

    function swapExactETHForTokens(
        address tokenOut,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external payable nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(deadline >= block.timestamp, "Expired");
        require(msg.value > 0, "Zero amount");
        require(isTokenAccepted(tokenOut), "Token not accepted");

        // Calculate output amount using HydraCurve
        IHydraCurve curve = IHydraCurve(registry.getContractAddressByName("HYDRA_CURVE"));
        amountOut = curve.calculatePrice(tokenOut, msg.value);

        // Apply fees
        uint256 totalFee = (amountOut * swapFee) / FEE_DENOMINATOR;
        uint256 protocolAmount = (totalFee * protocolFee) / swapFee;
        uint256 lpAmount = (totalFee * lpFee) / swapFee;
        amountOut = amountOut - totalFee;

        require(amountOut >= minAmountOut, "Insufficient output");

        // Handle fees
        if (protocolAmount > 0) {
            IERC20(tokenOut).transfer(feeCollector, protocolAmount);
        }
        if (lpAmount > 0) {
            // Add to liquidity pool (to be implemented)
            IERC20(tokenOut).transfer(address(this), lpAmount);
        }

        // Transfer tokens to recipient
        IERC20(tokenOut).transfer(to, amountOut);

        emit Swap(
            msg.sender,
            WETH,
            tokenOut,
            msg.value,
            amountOut,
            totalFee
        );
    }

    function swapExactTokensForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address payable to,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(deadline >= block.timestamp, "Expired");
        require(amountIn > 0, "Zero amount");
        require(isTokenAccepted(tokenIn), "Token not accepted");

        // Transfer tokens from user
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Calculate output amount using HydraCurve
        IHydraCurve curve = IHydraCurve(registry.getContractAddressByName("HYDRA_CURVE"));
        amountOut = curve.calculatePrice(WETH, amountIn);

        // Apply fees
        uint256 totalFee = (amountOut * swapFee) / FEE_DENOMINATOR;
        uint256 protocolAmount = (totalFee * protocolFee) / swapFee;
        uint256 lpAmount = (totalFee * lpFee) / swapFee;
        amountOut = amountOut - totalFee;

        require(amountOut >= minAmountOut, "Insufficient output");
        require(address(this).balance >= amountOut, "Insufficient ETH");

        // Handle fees
        if (protocolAmount > 0) {
            payable(feeCollector).transfer(protocolAmount);
        }
        if (lpAmount > 0) {
            // Add to liquidity pool (to be implemented)
            // Keep ETH in contract
        }

        // Transfer ETH to recipient
        to.transfer(amountOut);

        emit Swap(
            msg.sender,
            tokenIn,
            WETH,
            amountIn,
            amountOut,
            totalFee
        );
    }

    // View functions
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        IHydraCurve curve = IHydraCurve(registry.getContractAddressByName("HYDRA_CURVE"));
        amountOut = curve.calculatePrice(tokenOut, amountIn);

        // Apply fees
        uint256 totalFee = (amountOut * swapFee) / FEE_DENOMINATOR;
        amountOut = amountOut - totalFee;
    }

    function getPriceImpact(
        address token,
        uint256 amount,
        bool isBuy
    ) external view returns (uint256) {
        IHydraCurve curve = IHydraCurve(registry.getContractAddressByName("HYDRA_CURVE"));
        return curve.calculatePriceImpact(token, amount, isBuy);
    }

    // Admin functions
    function setFees(
        uint256 _swapFee,
        uint256 _protocolFee,
        uint256 _lpFee
    ) external onlyOwner {
        require(_swapFee <= MAX_FEE, "Fee too high");
        require(_protocolFee + _lpFee == _swapFee, "Invalid fee split");

        swapFee = _swapFee;
        protocolFee = _protocolFee;
        lpFee = _lpFee;

        emit FeeUpdated(_swapFee, _protocolFee, _lpFee);
    }

    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router");
        swapRouter = _router;
        emit RouterUpdated(_router);
    }

    function setPriceOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle");
        priceOracle = _oracle;
        emit PriceOracleUpdated(_oracle);
    }

    function setFeeCollector(address _collector) external onlyOwner {
        require(_collector != address(0), "Invalid collector");
        feeCollector = _collector;
        emit FeeCollectorUpdated(_collector);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Token management functions
    function setAcceptedToken(address token, bool status) external onlyOwner {
        require(token != address(0), "Invalid token");
        acceptedTokens[token] = status;
        emit TokenAccepted(token, status);
    }

    function registerD4LToken(address token, bool status) external {
        require(msg.sender == registry.getContractAddressByName("TOKEN_FACTORY"), "Only factory");
        require(token != address(0), "Invalid token");
        isD4LToken[token] = status;
        if (status) {
            acceptedTokens[token] = true;
            emit TokenAccepted(token, true);
        }
        emit D4LTokenRegistered(token, status);
    }

    function isTokenAccepted(address token) public view returns (bool) {
        return acceptedTokens[token] || isD4LToken[token];
    }

    // Fallback functions
    receive() external payable {}
    fallback() external payable {}
} 