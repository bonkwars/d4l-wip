// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../registry/ContractRegistry.sol";
import "./TokenFactory.sol";
import "../interfaces/IHydraCurve.sol";
import "../interfaces/ISocialModule.sol";
import "../interfaces/ISecurityModule.sol";
import "../interfaces/ILiquidityModule.sol";

/**
 * @title EasyTokenCreator
 * @notice Simplified interface for creating tokens with automated settings
 * @dev Abstracts complexity of token creation process with sensible defaults
 */
contract EasyTokenCreator is AccessControl {
    ContractRegistry public immutable registry;
    
    // Default values
    uint256 private constant DEFAULT_INITIAL_SUPPLY = 1000000 * 1e18; // 1M tokens
    uint256 private constant DEFAULT_INITIAL_LIQUIDITY = 100000 * 1e18; // 10% of supply
    uint256 private constant DEFAULT_MIN_LIQUIDITY = 10000 * 1e18; // 1% of supply
    uint256 private constant DEFAULT_LOCK_DURATION = 30 days;
    uint16 private constant DEFAULT_SWAP_FEE = 300; // 3%
    
    // Fee distribution percentages (in basis points, 100 = 1%)
    uint16 private constant COMMUNITY_FEE = 2500;    // 25% to community pool
    uint16 private constant TEAM_FEE = 2000;         // 20% to team pool
    uint16 private constant DEX_LIQUIDITY_FEE = 3000;// 30% to DEX liquidity pool
    uint16 private constant TREASURY_FEE = 1000;     // 10% to treasury
    uint16 private constant MARKETING_FEE = 1000;    // 10% to marketing pool
    uint16 private constant CEX_LIQUIDITY_FEE = 500; // 5% to CEX liquidity pool
    
    // Events
    event TokenCreated(
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 initialSupply,
        uint256 initialLiquidity
    );
    
    constructor(address _registry) {
        require(_registry != address(0), "Invalid registry");
        registry = ContractRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice Creates a new token with simplified parameters and sensible defaults
     * @param name Token name
     * @param symbol Token symbol
     * @param description Token description
     * @param metadataURI IPFS URI for token metadata
     */
    function createToken(
        string calldata name,
        string calldata symbol,
        string calldata description,
        string calldata metadataURI
    ) external {
        // Get contract addresses
        address tokenFactory = registry.getContractAddress(registry.TOKEN_FACTORY());
        address securityModule = registry.getContractAddress(keccak256("SECURITY_MODULE"));
        address liquidityModule = registry.getContractAddress(keccak256("LIQUIDITY_MODULE"));
        address socialModule = registry.getContractAddress(keccak256("SOCIAL_MODULE"));
        
        // Get pool addresses
        address communityPool = registry.getContractAddress(keccak256("COMMUNITY_POOL"));
        address teamPool = registry.getContractAddress(keccak256("TEAM_POOL"));
        address dexLiquidityPool = registry.getContractAddress(keccak256("DEX_LIQUIDITY_POOL"));
        address treasuryPool = registry.getContractAddress(keccak256("TREASURY_POOL"));
        address marketingPool = registry.getContractAddress(keccak256("MARKETING_POOL"));
        address cexLiquidityPool = registry.getContractAddress(keccak256("CEX_LIQUIDITY_POOL"));
        
        // Configure security settings
        ISecurityModule.SecurityConfig memory securityConfig = ISecurityModule.SecurityConfig({
            maxTransactionAmount: DEFAULT_INITIAL_SUPPLY / 100, // 1% max tx
            timeWindow: 1 hours,
            maxTransactionsPerWindow: 100,
            lockDuration: DEFAULT_LOCK_DURATION,
            minLiquidityPercentage: 5000, // 50%
            maxSellPercentage: 1000 // 10%
        });
        
        // Configure liquidity settings
        ILiquidityModule.PoolParameters memory poolParams = ILiquidityModule.PoolParameters({
            initialLiquidity: DEFAULT_INITIAL_LIQUIDITY,
            minLiquidity: DEFAULT_MIN_LIQUIDITY,
            maxLiquidity: DEFAULT_INITIAL_SUPPLY,
            lockDuration: DEFAULT_LOCK_DURATION,
            swapFee: DEFAULT_SWAP_FEE,
            autoLiquidity: true
        });
        
        // Configure social settings
        ISocialModule.TokenGateConfig memory gateConfig = ISocialModule.TokenGateConfig({
            minHoldAmount: DEFAULT_INITIAL_SUPPLY / 1000, // 0.1% min hold
            minHoldDuration: 7 days,
            requiredLevel: 1,
            requireVerification: false,
            enableTrading: true,
            enableStaking: true
        });
        
        // Create token with all configurations
        address token = TokenFactory(tokenFactory).createToken(
            name,
            symbol,
            DEFAULT_INITIAL_SUPPLY
        );
        
        // Configure fee distribution
        ILiquidityModule(liquidityModule).setFeeDistribution(
            token,
            communityPool, COMMUNITY_FEE,
            teamPool, TEAM_FEE,
            dexLiquidityPool, DEX_LIQUIDITY_FEE,
            treasuryPool, TREASURY_FEE,
            marketingPool, MARKETING_FEE,
            cexLiquidityPool, CEX_LIQUIDITY_FEE
        );
        
        // Update security config
        ISecurityModule(securityModule).updateSecurityConfig(
            bytes32(uint256(uint160(token))),
            securityConfig
        );
        
        
        // Initialize liquidity pool
        ILiquidityModule(liquidityModule).initializePool(token, poolParams, msg.sender);
        
        // Create token gate
        ISocialModule(socialModule).createTokenGate(
            token,
            gateConfig.minHoldAmount,
            gateConfig.minHoldDuration,
            gateConfig.requiredLevel,
            gateConfig.requireVerification,
            gateConfig.enableTrading,
            gateConfig.enableStaking
        );
        
        emit TokenCreated(
            token,
            msg.sender,
            name,
            symbol,
            DEFAULT_INITIAL_SUPPLY,
            DEFAULT_INITIAL_LIQUIDITY
        );
    }
    
    /**
     * @notice Gets the default parameters used for token creation
     */
    function getDefaultParameters() external pure returns (
        uint256 initialSupply,
        uint256 initialLiquidity,
        uint256 minLiquidity,
        uint256 lockDuration,
        uint16 swapFee,
        uint16 communityFee,
        uint16 teamFee,
        uint16 dexLiquidityFee,
        uint16 treasuryFee,
        uint16 marketingFee,
        uint16 cexLiquidityFee
    ) {
        return (
            DEFAULT_INITIAL_SUPPLY,
            DEFAULT_INITIAL_LIQUIDITY,
            DEFAULT_MIN_LIQUIDITY,
            DEFAULT_LOCK_DURATION,
            DEFAULT_SWAP_FEE,
            COMMUNITY_FEE,
            TEAM_FEE,
            DEX_LIQUIDITY_FEE,
            TREASURY_FEE,
            MARKETING_FEE,
            CEX_LIQUIDITY_FEE
        );
    }
} 