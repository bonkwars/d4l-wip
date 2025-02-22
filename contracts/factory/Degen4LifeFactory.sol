// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../proxy/Degen4LifeProxy.sol";
import "../registry/ContractRegistry.sol";

contract Degen4LifeFactory is AccessControl {
    ContractRegistry public immutable registry;
    
    event ContractDeployed(bytes32 indexed contractType, address indexed contractAddress);
    
    constructor(address _registry) {
        require(_registry != address(0), "Invalid registry");
        registry = ContractRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function deployProxiedContract(
        bytes32 contractType,
        address implementation,
        bytes memory initData
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (address) {
        // Deploy proxy admin
        Degen4LifeProxyAdmin proxyAdmin = new Degen4LifeProxyAdmin(msg.sender);
        
        // Deploy proxy
        Degen4LifeProxy proxy = new Degen4LifeProxy(
            implementation,
            address(proxyAdmin),
            initData
        );
        
        // Register the proxy address
        registry.setContractAddress(contractType, address(proxy));
        
        emit ContractDeployed(contractType, address(proxy));
        return address(proxy);
    }
    
    function deployContract(
        bytes32 contractType,
        address implementation
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (address) {
        // Register the implementation address
        registry.setContractAddress(contractType, implementation);
        
        emit ContractDeployed(contractType, implementation);
        return implementation;
    }
} 