// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseModule.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IHydraAMM.sol";
import "../interfaces/ILiquidityRouter.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../mocks/MockERC20.sol";

/**
 * @title LiquidityRouter
 * @notice Handles fee collection and distribution to various protocol pools
 * @dev Routes transaction fees to community, team, DEX liquidity, treasury, marketing, CEX liquidity pools, and buyback/burn
 */
contract LiquidityRouter is Initializable, ERC165, BaseModule, ILiquidityRouter {
    bytes32 public constant ROUTER_ADMIN = keccak256("ROUTER_ADMIN");
    
    // Fee distribution percentages (in basis points, 100 = 1%)
    uint16 public constant COMMUNITY_FEE = 2000;    // 20% to community pool
    uint16 public constant TEAM_FEE = 1500;         // 15% to team pool
    uint16 public constant DEX_LIQUIDITY_FEE = 2500;// 25% to DEX liquidity pool
    uint16 public constant TREASURY_FEE = 1000;     // 10% to treasury
    uint16 public constant MARKETING_FEE = 1000;    // 10% to marketing pool
    uint16 public constant CEX_LIQUIDITY_FEE = 500; // 5% to CEX liquidity pool
    uint16 public constant BUYBACK_FEE = 1500;      // 15% to buyback and burn

    // Buyback threshold
    uint256 public constant BUYBACK_THRESHOLD = 1000 * 1e18; // 1000 tokens

    // Dead address for token burns
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _registry) external initializer {
        __BaseModule_init(_registry);
        _grantRole(ROUTER_ADMIN, msg.sender);
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, AccessControlUpgradeable) returns (bool) {
        return
            interfaceId == type(ILiquidityRouter).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Collects and distributes fees
     * @param token The token address
     * @param amount The amount of fees to distribute
     */
    function collectAndDistributeFees(
        address token,
        uint256 amount
    ) external override nonReentrant whenNotPaused {
        require(amount > 0, "Zero amount");
        
        // Transfer tokens from sender
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        // Calculate fee distribution
        (
            uint256 communityAmount,
            uint256 teamAmount,
            uint256 dexLiquidityAmount,
            uint256 treasuryAmount,
            uint256 marketingAmount,
            uint256 cexLiquidityAmount,
            uint256 buybackAmount
        ) = calculateFeeDistribution(amount);
        
        // Distribute fees
        _distributeFees(
            token,
            communityAmount,
            teamAmount,
            dexLiquidityAmount,
            treasuryAmount,
            marketingAmount,
            cexLiquidityAmount
        );
        
        // Handle buyback and burn if threshold is met
        if (buybackAmount >= BUYBACK_THRESHOLD) {
            _buybackAndBurn(token, buybackAmount);
        }
        
        emit FeesCollected(token, msg.sender, amount, block.timestamp);
    }

    /**
     * @notice Calculates fee distribution for a given amount
     */
    function calculateFeeDistribution(
        uint256 amount
    ) public pure override returns (
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexLiquidityAmount,
        uint256 treasuryAmount,
        uint256 marketingAmount,
        uint256 cexLiquidityAmount,
        uint256 buybackAmount
    ) {
        communityAmount = (amount * COMMUNITY_FEE) / 10000;
        teamAmount = (amount * TEAM_FEE) / 10000;
        dexLiquidityAmount = (amount * DEX_LIQUIDITY_FEE) / 10000;
        treasuryAmount = (amount * TREASURY_FEE) / 10000;
        marketingAmount = (amount * MARKETING_FEE) / 10000;
        cexLiquidityAmount = (amount * CEX_LIQUIDITY_FEE) / 10000;
        buybackAmount = (amount * BUYBACK_FEE) / 10000;
    }

    /**
     * @notice Gets the total fee percentage
     */
    function getTotalFee() external pure override returns (uint16) {
        return COMMUNITY_FEE + TEAM_FEE + DEX_LIQUIDITY_FEE + TREASURY_FEE + 
               MARKETING_FEE + CEX_LIQUIDITY_FEE + BUYBACK_FEE;
    }

    /**
     * @notice Gets individual fee percentages
     */
    function getFeePercentages() external pure override returns (
        uint16 communityFee,
        uint16 teamFee,
        uint16 dexLiquidityFee,
        uint16 treasuryFee,
        uint16 marketingFee,
        uint16 cexLiquidityFee,
        uint16 buybackFee
    ) {
        return (
            COMMUNITY_FEE,
            TEAM_FEE,
            DEX_LIQUIDITY_FEE,
            TREASURY_FEE,
            MARKETING_FEE,
            CEX_LIQUIDITY_FEE,
            BUYBACK_FEE
        );
    }

    /**
     * @dev Internal function to distribute fees to various pools
     */
    function _distributeFees(
        address token,
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexLiquidityAmount,
        uint256 treasuryAmount,
        uint256 marketingAmount,
        uint256 cexLiquidityAmount
    ) internal {
        address communityPool = getContractAddress(keccak256("COMMUNITY_POOL"));
        address teamPool = getContractAddress(keccak256("TEAM_POOL"));
        address dexLiquidityPool = getContractAddress(keccak256("DEX_LIQUIDITY_POOL"));
        address treasury = getContractAddress(keccak256("TREASURY"));
        address marketingPool = getContractAddress(keccak256("MARKETING_POOL"));
        address cexLiquidityPool = getContractAddress(keccak256("CEX_LIQUIDITY_POOL"));

        IERC20(token).transfer(communityPool, communityAmount);
        IERC20(token).transfer(teamPool, teamAmount);
        IERC20(token).transfer(dexLiquidityPool, dexLiquidityAmount);
        IERC20(token).transfer(treasury, treasuryAmount);
        IERC20(token).transfer(marketingPool, marketingAmount);
        IERC20(token).transfer(cexLiquidityPool, cexLiquidityAmount);

        emit FeesDistributed(
            token,
            communityAmount,
            teamAmount,
            dexLiquidityAmount,
            treasuryAmount,
            marketingAmount,
            cexLiquidityAmount,
            0 // buybackAmount will be handled separately
        );
    }

    /**
     * @dev Internal function to perform buyback and burn
     */
    function _buybackAndBurn(address token, uint256 amount) internal {
        address hydraAMM = getContractAddress(keccak256("HYDRA_AMM"));
        
        // Approve AMM to spend tokens
        IERC20(token).approve(hydraAMM, amount);
        
        // Set up path for swap
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(0);
        
        // Perform swap to buy back tokens
        uint256[] memory amounts = IHydraAMM(hydraAMM).swap(
            amount,
            0, // Accept any amount of output tokens
            path,
            address(this),
            block.timestamp
        );
        
        // Burn the bought back tokens using MockERC20 interface
        IERC20(token).approve(token, amounts[1]);
        MockERC20(token).burn(address(this), amounts[1]);
        
        emit TokensBoughtBack(token, amount, amounts[1]);
        emit TokensBurned(token, amounts[1]);
    }

    // Add receive function to accept ETH
    receive() external payable {}
}