// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../registry/ContractRegistry.sol";

contract FalconVerifier is AccessControl {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    ContractRegistry public immutable registry;
    
    // Mapping to store public keys
    mapping(address => bytes) public publicKeys;
    // Mapping to track verified addresses
    mapping(address => bool) public verifiedAddresses;
    
    // Events
    event PublicKeyRegistered(address indexed user, bytes publicKey);
    event AddressVerified(address indexed user, bool status);
    event SignatureVerified(address indexed user, bool success);
    
    constructor(address _registry) {
        require(_registry != address(0), "Invalid registry");
        registry = ContractRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
    }
    
    function registerPublicKey(bytes calldata publicKey) external {
        require(publicKey.length > 0, "Invalid public key");
        publicKeys[msg.sender] = publicKey;
        emit PublicKeyRegistered(msg.sender, publicKey);
    }
    
    function verifyAddress(address user) external onlyRole(VERIFIER_ROLE) {
        require(publicKeys[user].length > 0, "No public key");
        verifiedAddresses[user] = true;
        emit AddressVerified(user, true);
    }
    
    function verifySignature(
        address user,
        bytes calldata signature
    ) external returns (bool) {
        require(verifiedAddresses[user], "Address not verified");
        require(signature.length > 0, "Invalid signature");
        
        // TODO: Implement actual Falcon signature verification
        // This is a placeholder that always returns true
        bool success = true;
        
        emit SignatureVerified(user, success);
        return success;
    }
    
    function revokeVerification(address user) external onlyRole(VERIFIER_ROLE) {
        verifiedAddresses[user] = false;
        emit AddressVerified(user, false);
    }
    
    function isVerified(address user) external view returns (bool) {
        return verifiedAddresses[user];
    }
    
    function getPublicKey(address user) external view returns (bytes memory) {
        return publicKeys[user];
    }
}
