// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../Degen4LifeRoles.sol";

contract ContractRegistry is AccessControl {
    // Contract address mapping
    mapping(bytes32 => address) private _contracts;
    
    // Events
    event ContractAddressUpdated(bytes32 indexed id, address indexed addr);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    // Contract identifiers
    bytes32 public constant CONTROLLER = keccak256("CONTROLLER");
    bytes32 public constant TOKEN_FACTORY = keccak256("TOKEN_FACTORY");
    bytes32 public constant POOL_CONTROLLER = keccak256("POOL_CONTROLLER");
    bytes32 public constant USER_PROFILE = keccak256("USER_PROFILE");
    bytes32 public constant FEE_HANDLER = keccak256("FEE_HANDLER");
    bytes32 public constant ANTI_BOT = keccak256("ANTI_BOT");
    bytes32 public constant ANTI_RUGPULL = keccak256("ANTI_RUGPULL");
    bytes32 public constant DAO = keccak256("DAO");
    bytes32 public constant VERSION_CONTROLLER = keccak256("VERSION_CONTROLLER");
    bytes32 public constant HYDRA_CURVE = keccak256("HYDRA_CURVE");
    bytes32 public constant SOCIAL_ORACLE = keccak256("SOCIAL_ORACLE");
    
    function setContractAddress(bytes32 id, address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(addr != address(0), "Invalid address");
        _contracts[id] = addr;
        emit ContractAddressUpdated(id, addr);
    }
    
    function getContractAddress(bytes32 id) external view returns (address) {
        address addr = _contracts[id];
        require(addr != address(0), "Contract not registered");
        return addr;
    }
    
    function removeContractAddress(bytes32 id) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_contracts[id] != address(0), "Contract not registered");
        delete _contracts[id];
        emit ContractAddressUpdated(id, address(0));
    }
    
    // Batch update for gas optimization
    function batchSetContractAddresses(
        bytes32[] calldata ids,
        address[] calldata addrs
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(ids.length == addrs.length, "Length mismatch");
        for (uint i = 0; i < ids.length; i++) {
            require(addrs[i] != address(0), "Invalid address");
            _contracts[ids[i]] = addrs[i];
            emit ContractAddressUpdated(ids[i], addrs[i]);
        }
    }
} 