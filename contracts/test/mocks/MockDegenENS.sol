// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../registry/ContractRegistry.sol";

contract MockDegenENS is AccessControl {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    
    ContractRegistry public immutable registry;
    
    // Mapping from name hash to resolver
    mapping(bytes32 => address) private _resolvers;
    // Mapping from name hash to owner
    mapping(bytes32 => address) private _owners;
    // Mapping from name to expiry timestamp
    mapping(bytes32 => uint256) private _expiryTimes;
    
    // Events
    event NameRegistered(bytes32 indexed nameHash, address indexed owner, uint256 expiryTime);
    event NameTransferred(bytes32 indexed nameHash, address indexed oldOwner, address indexed newOwner);
    event ResolverUpdated(bytes32 indexed nameHash, address indexed resolver);
    event NameRenewed(bytes32 indexed nameHash, uint256 newExpiryTime);
    
    constructor(address _registry) {
        require(_registry != address(0), "Invalid registry");
        registry = ContractRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRAR_ROLE, msg.sender);
    }
    
    function registerName(
        string calldata name,
        address owner,
        uint256 duration
    ) external {
        bytes32 nameHash = keccak256(bytes(name));
        require(_owners[nameHash] == address(0) || block.timestamp >= _expiryTimes[nameHash], "Name already registered");
        
        _owners[nameHash] = owner;
        _expiryTimes[nameHash] = block.timestamp + duration;
        
        emit NameRegistered(nameHash, owner, _expiryTimes[nameHash]);
    }
    
    function setResolver(
        bytes32 nameHash,
        address resolver
    ) external {
        require(msg.sender == _owners[nameHash] && block.timestamp < _expiryTimes[nameHash], "Not name owner");
        require(resolver != address(0), "Invalid resolver");
        
        _resolvers[nameHash] = resolver;
        emit ResolverUpdated(nameHash, resolver);
    }
    
    function transferName(
        bytes32 nameHash,
        address newOwner
    ) external {
        require(msg.sender == _owners[nameHash] && block.timestamp < _expiryTimes[nameHash], "Not name owner");
        require(newOwner != address(0), "Invalid new owner");
        
        address oldOwner = _owners[nameHash];
        _owners[nameHash] = newOwner;
        
        emit NameTransferred(nameHash, oldOwner, newOwner);
    }
    
    function renewName(
        bytes32 nameHash,
        uint256 duration
    ) external {
        require(_owners[nameHash] != address(0), "Name not registered");
        
        _expiryTimes[nameHash] = block.timestamp + duration;
        emit NameRenewed(nameHash, _expiryTimes[nameHash]);
    }
    
    function resolveAddress(bytes32 nameHash) external view returns (address) {
        return _resolvers[nameHash];
    }
    
    function getOwner(bytes32 nameHash) external view returns (address) {
        return _owners[nameHash];
    }
    
    function getResolver(bytes32 nameHash) external view returns (address) {
        return _resolvers[nameHash];
    }
    
    function getExpiryTime(bytes32 nameHash) external view returns (uint256) {
        return _expiryTimes[nameHash];
    }
    
    function isExpired(bytes32 nameHash) external view returns (bool) {
        return block.timestamp >= _expiryTimes[nameHash];
    }
} 