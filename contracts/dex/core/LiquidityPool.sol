// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IContractRegistry.sol";

contract LiquidityPool is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable 
{
    // State variables
    IContractRegistry public registry;
    address public WETH;
    
    struct Pool {
        uint256 tokenReserve;
        uint256 ethReserve;
        uint256 totalLiquidity;
        uint256 lastUpdateTime;
    }

    mapping(address => Pool) private _pools;
    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    // Events
    event LiquidityAdded(
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
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

    function addLiquidity(
        address token,
        uint256 tokenAmount,
        uint256 minLiquidity,
        uint256 deadline
    ) external payable nonReentrant whenNotPaused returns (uint256 liquidity) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(tokenAmount >= MINIMUM_LIQUIDITY, "Insufficient liquidity");
        require(msg.value >= MINIMUM_LIQUIDITY, "Insufficient ETH");

        Pool storage pool = _pools[token];
        
        // Calculate optimal amounts
        (uint256 optimalTokenAmount, uint256 optimalEthAmount) = getOptimalAmounts(
            token,
            tokenAmount,
            msg.value
        );

        // Transfer tokens
        IERC20(token).transferFrom(msg.sender, address(this), optimalTokenAmount);

        // Update pool
        pool.tokenReserve += optimalTokenAmount;
        pool.ethReserve += optimalEthAmount;
        
        // Calculate liquidity
        liquidity = _calculateLiquidity(pool, optimalTokenAmount, optimalEthAmount);
        require(liquidity >= minLiquidity, "Insufficient liquidity minted");

        pool.totalLiquidity += liquidity;
        pool.lastUpdateTime = block.timestamp;

        emit LiquidityAdded(msg.sender, optimalTokenAmount, optimalEthAmount, liquidity);
    }

    function removeLiquidity(
        address token,
        uint256 liquidity,
        uint256 minTokenAmount,
        uint256 minEthAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 tokenAmount, uint256 ethAmount) {
        require(block.timestamp <= deadline, "Transaction expired");
        Pool storage pool = _pools[token];
        require(liquidity > 0 && liquidity <= pool.totalLiquidity, "Invalid liquidity");

        // Calculate amounts
        tokenAmount = (liquidity * pool.tokenReserve) / pool.totalLiquidity;
        ethAmount = (liquidity * pool.ethReserve) / pool.totalLiquidity;

        require(tokenAmount >= minTokenAmount, "Insufficient token amount");
        require(ethAmount >= minEthAmount, "Insufficient ETH amount");

        // Update pool
        pool.tokenReserve -= tokenAmount;
        pool.ethReserve -= ethAmount;
        pool.totalLiquidity -= liquidity;
        pool.lastUpdateTime = block.timestamp;

        // Transfer assets
        IERC20(token).transfer(msg.sender, tokenAmount);
        payable(msg.sender).transfer(ethAmount);

        emit LiquidityRemoved(msg.sender, tokenAmount, ethAmount, liquidity);
    }

    function getReserves(address token) external view returns (uint256 tokenReserve, uint256 ethReserve) {
        Pool storage pool = _pools[token];
        return (pool.tokenReserve, pool.ethReserve);
    }

    function getOptimalAmounts(
        address token,
        uint256 tokenAmount,
        uint256 ethAmount
    ) public view returns (uint256 optimalTokenAmount, uint256 optimalEthAmount) {
        Pool storage pool = _pools[token];
        
        if (pool.tokenReserve == 0 && pool.ethReserve == 0) {
            return (tokenAmount, ethAmount);
        }

        uint256 optimalEth = (tokenAmount * pool.ethReserve) / pool.tokenReserve;
        if (optimalEth <= ethAmount) {
            return (tokenAmount, optimalEth);
        }

        uint256 optimalToken = (ethAmount * pool.tokenReserve) / pool.ethReserve;
        return (optimalToken, ethAmount);
    }

    function _calculateLiquidity(
        Pool storage pool,
        uint256 tokenAmount,
        uint256 ethAmount
    ) internal view returns (uint256) {
        if (pool.totalLiquidity == 0) {
            return _sqrt(tokenAmount * ethAmount);
        }
        return min(
            (tokenAmount * pool.totalLiquidity) / pool.tokenReserve,
            (ethAmount * pool.totalLiquidity) / pool.ethReserve
        );
    }

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

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    receive() external payable {
        require(msg.sender == WETH, "Direct deposits not allowed");
    }
} 