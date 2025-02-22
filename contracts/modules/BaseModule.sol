// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../registry/ContractRegistry.sol";

abstract contract BaseModule is Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    ContractRegistry public registry;
    
    // Events
    event ModuleInitialized(address indexed module);
    event ModuleUpgraded(address indexed module, uint256 version);
    
    // Error messages
    error Unauthorized();
    error InvalidAddress();
    error InvalidParameters();
    error ModuleNotInitialized();
    
    function __BaseModule_init(address _registry) internal onlyInitializing {
        if (_registry == address(0)) revert InvalidAddress();
        registry = ContractRegistry(_registry);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        emit ModuleInitialized(address(this));
    }
    
    // Modifier to check if caller is a registered contract
    modifier onlyRegisteredContract(bytes32 contractType) {
        if (msg.sender != registry.getContractAddress(contractType)) 
            revert Unauthorized();
        _;
    }
    
    // Get contract address from registry with validation
    function getContractAddress(bytes32 contractType) internal view returns (address) {
        address addr = registry.getContractAddress(contractType);
        if (addr == address(0)) revert InvalidAddress();
        return addr;
    }
    
    // Pause functionality
    function pause() external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    // Version tracking
    uint256 private _version;
    
    function getVersion() external view returns (uint256) {
        return _version;
    }
    
    function _upgradeToVersion(uint256 newVersion) internal {
        require(newVersion > _version, "Invalid version");
        _version = newVersion;
        emit ModuleUpgraded(address(this), newVersion);
    }
} 