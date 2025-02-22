// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IDegen4LifeDEX.sol";

contract SwapRouter is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable 
{
    // State variables
    IDegen4LifeDEX public dex;
    address public WETH;
    mapping(address => bool) public whitelistedCallers;

    // Events
    event CallerWhitelisted(address indexed caller, bool status);
    event SwapRouted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _dex,
        address _weth
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_dex != address(0), "Invalid DEX");
        require(_weth != address(0), "Invalid WETH");

        dex = IDegen4LifeDEX(_dex);
        WETH = _weth;

        // Whitelist deployer
        whitelistedCallers[msg.sender] = true;
        emit CallerWhitelisted(msg.sender, true);
    }

    // External functions
    function routeSwapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(whitelistedCallers[msg.sender], "Caller not whitelisted");

        // Ensure router has approval
        require(
            IERC20(tokenIn).allowance(msg.sender, address(this)) >= amountIn,
            "Insufficient allowance"
        );

        // Transfer tokens to router
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Approve DEX
        IERC20(tokenIn).approve(address(dex), amountIn);

        // Execute swap
        amountOut = dex.swapExactTokensForTokens(
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            to,
            deadline
        );

        emit SwapRouted(
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut
        );
    }

    function routeSwapExactETHForTokens(
        address tokenOut,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external payable nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(whitelistedCallers[msg.sender], "Caller not whitelisted");

        // Execute swap
        amountOut = dex.swapExactETHForTokens{value: msg.value}(
            tokenOut,
            minAmountOut,
            to,
            deadline
        );

        emit SwapRouted(
            msg.sender,
            WETH,
            tokenOut,
            msg.value,
            amountOut
        );
    }

    function routeSwapExactTokensForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address payable to,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(whitelistedCallers[msg.sender], "Caller not whitelisted");

        // Ensure router has approval
        require(
            IERC20(tokenIn).allowance(msg.sender, address(this)) >= amountIn,
            "Insufficient allowance"
        );

        // Transfer tokens to router
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Approve DEX
        IERC20(tokenIn).approve(address(dex), amountIn);

        // Execute swap
        amountOut = dex.swapExactTokensForETH(
            tokenIn,
            amountIn,
            minAmountOut,
            to,
            deadline
        );

        emit SwapRouted(
            msg.sender,
            tokenIn,
            WETH,
            amountIn,
            amountOut
        );
    }

    // View functions
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        return dex.getAmountOut(tokenIn, tokenOut, amountIn);
    }

    function getPriceImpact(
        address token,
        uint256 amount,
        bool isBuy
    ) external view returns (uint256) {
        return dex.getPriceImpact(token, amount, isBuy);
    }

    // Admin functions
    function setWhitelistedCaller(
        address caller,
        bool status
    ) external onlyOwner {
        whitelistedCallers[caller] = status;
        emit CallerWhitelisted(caller, status);
    }

    function setDEX(address _dex) external onlyOwner {
        require(_dex != address(0), "Invalid DEX");
        dex = IDegen4LifeDEX(_dex);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Emergency functions
    function rescueTokens(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    function rescueETH(
        address payable to,
        uint256 amount
    ) external onlyOwner {
        to.transfer(amount);
    }

    // Fallback functions
    receive() external payable {}
    fallback() external payable {}
} 