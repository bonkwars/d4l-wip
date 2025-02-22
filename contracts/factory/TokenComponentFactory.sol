// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IAntiBot.sol";
import "../interfaces/IAntiRugPull.sol";
import "../interfaces/ILiquidityModule.sol";
import "../interfaces/ISecurityModule.sol";
import "../registry/ContractRegistry.sol";

contract TokenComponentFactory is Ownable {
    using Clones for address;
    
    // Implementation addresses
    address public immutable antiBotImplementation;
    address public immutable antiRugPullImplementation;
    address public immutable liquidityModuleImplementation;
    address public immutable securityModuleImplementation;
    
    // Registry
    address public immutable registry;
    
    // Mappings to track token components
    mapping(address => address) public tokenToAntiBot;
    mapping(address => address) public tokenToAntiRugPull;
    mapping(address => address) public tokenToLiquidityModule;
    mapping(address => address) public tokenToSecurityModule;
    
    // Events
    event TokenComponentsCreated(
        address indexed token,
        address antiBotInstance,
        address antiRugPullInstance,
        address liquidityModuleInstance,
        address securityModuleInstance
    );
    
    constructor(
        address _antiBotImplementation,
        address _antiRugPullImplementation,
        address _liquidityModuleImplementation,
        address _securityModuleImplementation,
        address _registry
    ) Ownable(msg.sender) {
        require(_antiBotImplementation != address(0), "Invalid antiBot implementation");
        require(_antiRugPullImplementation != address(0), "Invalid antiRugPull implementation");
        require(_liquidityModuleImplementation != address(0), "Invalid liquidityModule implementation");
        require(_securityModuleImplementation != address(0), "Invalid securityModule implementation");
        require(_registry != address(0), "Invalid registry");
        
        antiBotImplementation = _antiBotImplementation;
        antiRugPullImplementation = _antiRugPullImplementation;
        liquidityModuleImplementation = _liquidityModuleImplementation;
        securityModuleImplementation = _securityModuleImplementation;
        registry = _registry;
    }
    
    function createTokenComponents(address token) external returns (
        address antiBotInstance,
        address antiRugPullInstance,
        address liquidityModuleInstance,
        address securityModuleInstance
    ) {
        require(token != address(0), "Invalid token address");
        require(tokenToAntiBot[token] == address(0), "Components already exist");
        
        // Create deterministic clones of each component
        antiBotInstance = Clones.cloneDeterministic(antiBotImplementation, keccak256(abi.encodePacked(token, "antiBot")));
        antiRugPullInstance = Clones.cloneDeterministic(antiRugPullImplementation, keccak256(abi.encodePacked(token, "antiRugPull")));
        liquidityModuleInstance = Clones.cloneDeterministic(liquidityModuleImplementation, keccak256(abi.encodePacked(token, "liquidityModule")));
        securityModuleInstance = Clones.cloneDeterministic(securityModuleImplementation, keccak256(abi.encodePacked(token, "securityModule")));
        
        // Initialize each component
        IAntiBot(antiBotInstance).initialize(token, address(registry));
        // Whitelist the token in AntiBot
        IAntiBot(antiBotInstance).whitelistAddress(token, true);

        IAntiRugPull(antiRugPullInstance).initialize(token, address(registry));
        // Configure anti-rug pull protection
        IAntiRugPull.LockConfig memory lockConfig = IAntiRugPull.LockConfig({
            lockDuration: 30 days,
            minLiquidityPercentage: 5000, // 50%
            maxSellPercentage: 1000, // 10%
            ownershipRenounced: false
        });
        IAntiRugPull(antiRugPullInstance).updateLockConfig(lockConfig);

        ILiquidityModule(liquidityModuleInstance).initialize(token, address(registry));
        ISecurityModule(securityModuleInstance).initialize(token, address(registry));

        // Get controller address
        address controller = ContractRegistry(address(registry)).getContractAddress(keccak256("CONTROLLER"));

        // Grant SECURITY_ADMIN role to the controller
        bytes32 SECURITY_ADMIN = keccak256("SECURITY_ADMIN");
        AccessControl(securityModuleInstance).grantRole(SECURITY_ADMIN, controller);

        // Grant POOL_MANAGER role to the controller
        bytes32 POOL_MANAGER = keccak256("POOL_MANAGER");
        AccessControl(liquidityModuleInstance).grantRole(POOL_MANAGER, controller);

        // Store component addresses
        tokenToAntiBot[token] = antiBotInstance;
        tokenToAntiRugPull[token] = antiRugPullInstance;
        tokenToLiquidityModule[token] = liquidityModuleInstance;
        tokenToSecurityModule[token] = securityModuleInstance;
        
        emit TokenComponentsCreated(token, antiBotInstance, antiRugPullInstance, liquidityModuleInstance, securityModuleInstance);
        return (antiBotInstance, antiRugPullInstance, liquidityModuleInstance, securityModuleInstance);
    }
    
    function getTokenComponents(address token) external view returns (
        address antiBotInstance,
        address antiRugPullInstance,
        address liquidityModuleInstance,
        address securityModuleInstance
    ) {
        antiBotInstance = Clones.predictDeterministicAddress(
            antiBotImplementation,
            keccak256(abi.encodePacked(token, "antiBot")),
            address(this)
        );
        antiRugPullInstance = Clones.predictDeterministicAddress(
            antiRugPullImplementation,
            keccak256(abi.encodePacked(token, "antiRugPull")),
            address(this)
        );
        liquidityModuleInstance = Clones.predictDeterministicAddress(
            liquidityModuleImplementation,
            keccak256(abi.encodePacked(token, "liquidityModule")),
            address(this)
        );
        securityModuleInstance = Clones.predictDeterministicAddress(
            securityModuleImplementation,
            keccak256(abi.encodePacked(token, "securityModule")),
            address(this)
        );
        
        return (antiBotInstance, antiRugPullInstance, liquidityModuleInstance, securityModuleInstance);
    }
} 