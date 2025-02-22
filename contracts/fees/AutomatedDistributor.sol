// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/ITokenomics.sol";
import "../constants/constants.sol";

/**
 * @title AutomatedDistributor
 * @notice Handles automated distribution of funds from treasury to various pools
 */
contract AutomatedDistributor is Ownable, ReentrancyGuard, Pausable {
    // Distribution percentages (total 100%)
    uint256 public constant COMMUNITY_POOL_SHARE = 25;
    uint256 public constant TEAM_POOL_SHARE = 20;
    uint256 public constant DEX_LIQUIDITY_SHARE = 30;
    uint256 public constant MARKETING_SHARE = 10;
    uint256 public constant CEX_LIQUIDITY_SHARE = 15;

    // Rate limiting
    uint256 public constant DISTRIBUTION_COOLDOWN = 1 days;
    uint256 public constant MAX_DISTRIBUTION_AMOUNT = 1000 ether;
    uint256 public lastDistributionTime;

    // Pool contracts
    address public communityPool;
    address public teamPool;
    address public dexLiquidityPool;
    address public marketingPool;
    address public cexLiquidityPool;
    address public treasury;

    // Events
    event DistributionProcessed(
        address indexed token,
        uint256 totalAmount,
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexLiquidityAmount,
        uint256 marketingAmount,
        uint256 cexLiquidityAmount
    );

    event PoolUpdated(string poolName, address indexed oldPool, address indexed newPool);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event EmergencyWithdrawal(address indexed token, uint256 amount, address indexed recipient);

    constructor(
        address _treasury,
        address _communityPool,
        address _teamPool,
        address _dexLiquidityPool,
        address _marketingPool,
        address _cexLiquidityPool
    ) Ownable(msg.sender) {
        require(_treasury != address(0), "Invalid treasury");
        require(_communityPool != address(0), "Invalid community pool");
        require(_teamPool != address(0), "Invalid team pool");
        require(_dexLiquidityPool != address(0), "Invalid DEX pool");
        require(_marketingPool != address(0), "Invalid marketing pool");
        require(_cexLiquidityPool != address(0), "Invalid CEX pool");

        treasury = _treasury;
        communityPool = _communityPool;
        teamPool = _teamPool;
        dexLiquidityPool = _dexLiquidityPool;
        marketingPool = _marketingPool;
        cexLiquidityPool = _cexLiquidityPool;
    }

    /**
     * @notice Distributes funds from treasury to various pools
     * @param token The token address (address(0) for ETH)
     * @param amount The amount to distribute
     */
    function distribute(
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Zero amount");
        require(amount <= MAX_DISTRIBUTION_AMOUNT, "Amount exceeds limit");
        require(block.timestamp >= lastDistributionTime + DISTRIBUTION_COOLDOWN, "Cooldown active");

        // Calculate amounts for each pool
        uint256 communityAmount = (amount * COMMUNITY_POOL_SHARE) / 100;
        uint256 teamAmount = (amount * TEAM_POOL_SHARE) / 100;
        uint256 dexLiquidityAmount = (amount * DEX_LIQUIDITY_SHARE) / 100;
        uint256 marketingAmount = (amount * MARKETING_SHARE) / 100;
        uint256 cexLiquidityAmount = (amount * CEX_LIQUIDITY_SHARE) / 100;

        // Transfer funds from treasury
        if (token == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH balance");
            _distributeETH(
                communityAmount,
                teamAmount,
                dexLiquidityAmount,
                marketingAmount,
                cexLiquidityAmount
            );
        } else {
            require(
                IERC20(token).transferFrom(treasury, address(this), amount),
                "Transfer from treasury failed"
            );
            _distributeToken(
                token,
                communityAmount,
                teamAmount,
                dexLiquidityAmount,
                marketingAmount,
                cexLiquidityAmount
            );
        }

        lastDistributionTime = block.timestamp;

        emit DistributionProcessed(
            token,
            amount,
            communityAmount,
            teamAmount,
            dexLiquidityAmount,
            marketingAmount,
            cexLiquidityAmount
        );
    }

    /**
     * @notice Updates a pool address
     * @param poolName Name of the pool to update
     * @param newPool New pool address
     */
    function updatePool(
        string calldata poolName,
        address newPool
    ) external onlyOwner {
        require(newPool != address(0), "Invalid pool address");

        address oldPool;
        if (keccak256(bytes(poolName)) == keccak256(bytes("community"))) {
            oldPool = communityPool;
            communityPool = newPool;
        } else if (keccak256(bytes(poolName)) == keccak256(bytes("team"))) {
            oldPool = teamPool;
            teamPool = newPool;
        } else if (keccak256(bytes(poolName)) == keccak256(bytes("dex"))) {
            oldPool = dexLiquidityPool;
            dexLiquidityPool = newPool;
        } else if (keccak256(bytes(poolName)) == keccak256(bytes("marketing"))) {
            oldPool = marketingPool;
            marketingPool = newPool;
        } else if (keccak256(bytes(poolName)) == keccak256(bytes("cex"))) {
            oldPool = cexLiquidityPool;
            cexLiquidityPool = newPool;
        } else {
            revert("Invalid pool name");
        }

        emit PoolUpdated(poolName, oldPool, newPool);
    }

    /**
     * @notice Updates the treasury address
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Pauses distributions
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses distributions
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdrawal of stuck funds
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        
        if (token == address(0)) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            require(IERC20(token).transfer(recipient, amount), "Token transfer failed");
        }

        emit EmergencyWithdrawal(token, amount, recipient);
    }

    /**
     * @notice Internal function to distribute ETH
     */
    function _distributeETH(
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexLiquidityAmount,
        uint256 marketingAmount,
        uint256 cexLiquidityAmount
    ) internal {
        (bool success1, ) = communityPool.call{value: communityAmount}("");
        require(success1, "Community transfer failed");

        (bool success2, ) = teamPool.call{value: teamAmount}("");
        require(success2, "Team transfer failed");

        (bool success3, ) = dexLiquidityPool.call{value: dexLiquidityAmount}("");
        require(success3, "DEX transfer failed");

        (bool success4, ) = marketingPool.call{value: marketingAmount}("");
        require(success4, "Marketing transfer failed");

        (bool success5, ) = cexLiquidityPool.call{value: cexLiquidityAmount}("");
        require(success5, "CEX transfer failed");
    }

    /**
     * @notice Internal function to distribute tokens
     */
    function _distributeToken(
        address token,
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexLiquidityAmount,
        uint256 marketingAmount,
        uint256 cexLiquidityAmount
    ) internal {
        require(IERC20(token).transfer(communityPool, communityAmount), "Community transfer failed");
        require(IERC20(token).transfer(teamPool, teamAmount), "Team transfer failed");
        require(IERC20(token).transfer(dexLiquidityPool, dexLiquidityAmount), "DEX transfer failed");
        require(IERC20(token).transfer(marketingPool, marketingAmount), "Marketing transfer failed");
        require(IERC20(token).transfer(cexLiquidityPool, cexLiquidityAmount), "CEX transfer failed");
    }

    receive() external payable {}
} 