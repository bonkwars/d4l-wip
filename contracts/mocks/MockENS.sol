// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IDegenENS.sol";

contract MockENS is IDegenENS {
    struct NameRecord {
        address owner;
        address resolver;
        uint256 expiryDate;
        bool exists;
    }

    mapping(bytes32 => NameRecord) public names;
    uint256 public constant REGISTRATION_PERIOD = 365 days;
    uint256 public constant REGISTRATION_FEE = 0.1 ether;

    function register(string calldata name) external payable returns (bytes32) {
        require(msg.value >= REGISTRATION_FEE, "Insufficient fee");
        bytes32 nameHash = keccak256(bytes(name));
        
        // Check if name is available (either never registered or expired)
        if (names[nameHash].owner != address(0)) {
            require(block.timestamp >= names[nameHash].expiryDate, "Name taken");
        }
        
        names[nameHash] = NameRecord({
            owner: msg.sender,
            resolver: address(0),
            expiryDate: block.timestamp + REGISTRATION_PERIOD,
            exists: true
        });
        
        return nameHash;
    }

    function renew(bytes32 nameHash) external payable {
        require(msg.value >= REGISTRATION_FEE, "Insufficient fee");
        require(names[nameHash].owner != address(0), "Name not registered");
        
        // Add a full period to the current expiry date or current time, whichever is later
        uint256 baseTime = names[nameHash].expiryDate > block.timestamp ? names[nameHash].expiryDate : block.timestamp;
        names[nameHash].expiryDate = baseTime + REGISTRATION_PERIOD;
    }

    function transfer(bytes32 nameHash, address newOwner) external {
        require(names[nameHash].owner == msg.sender, "Not owner");
        require(block.timestamp < names[nameHash].expiryDate, "Name expired");
        names[nameHash].owner = newOwner;
    }

    function getOwner(bytes32 nameHash) external view returns (address) {
        return names[nameHash].owner;
    }

    function getExpiryDate(bytes32 nameHash) external view returns (uint256) {
        return names[nameHash].expiryDate;
    }

    function registerName(string calldata name, address owner, uint256 duration) external override {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        require(!names[nameHash].exists || block.timestamp >= names[nameHash].expiryDate, "Name already registered");
        
        names[nameHash] = NameRecord({
            owner: owner,
            resolver: address(0),
            expiryDate: block.timestamp + duration,
            exists: true
        });
    }

    function setResolver(bytes32 nameHash, address resolver) external override {
        require(names[nameHash].exists, "Name not registered");
        require(names[nameHash].owner == msg.sender, "Not name owner");
        names[nameHash].resolver = resolver;
    }

    function transferName(bytes32 nameHash, address newOwner) external override {
        require(names[nameHash].exists, "Name not registered");
        require(names[nameHash].owner == msg.sender, "Not name owner");
        names[nameHash].owner = newOwner;
    }

    function renewName(bytes32 nameHash, uint256 duration) external override {
        require(names[nameHash].exists, "Name not registered");
        names[nameHash].expiryDate = block.timestamp + duration;
    }

    function resolve(bytes32 nameHash) external view override returns (address) {
        require(names[nameHash].exists, "Name not registered");
        return names[nameHash].resolver;
    }

    function getResolver(bytes32 nameHash) external view override returns (address) {
        require(names[nameHash].exists, "Name not registered");
        return names[nameHash].resolver;
    }

    function getExpiryTime(bytes32 nameHash) external view override returns (uint256) {
        require(names[nameHash].exists, "Name not registered");
        return names[nameHash].expiryDate;
    }

    function isExpired(bytes32 nameHash) external view override returns (bool) {
        if (!names[nameHash].exists) return true;
        return block.timestamp >= names[nameHash].expiryDate;
    }
} 