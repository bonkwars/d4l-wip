// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Degen4LifeACL {
    bytes32 public constant TOKEN_MANAGER = keccak256("TOKEN_MANAGER");
    bytes32 public constant POOL_OPERATOR = keccak256("POOL_OPERATOR");
    bytes32 public constant SECURITY_ADMIN = keccak256("SECURITY_ADMIN");
} 