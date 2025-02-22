// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Degen4LifeRoles {
    bytes32 public constant GOVERNANCE_ADMIN = keccak256("GOVERNANCE_ADMIN");
    bytes32 public constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE");
    bytes32 public constant TOKEN_CREATOR = keccak256("TOKEN_CREATOR");
    bytes32 public constant POOL_MANAGER = keccak256("POOL_MANAGER");
    bytes32 public constant SECURITY_ADMIN = keccak256("SECURITY_ADMIN");
    bytes32 public constant ORACLE_MANAGER = keccak256("ORACLE_MANAGER");
    bytes32 public constant BRIDGE_OPERATOR = keccak256("BRIDGE_OPERATOR");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
}

