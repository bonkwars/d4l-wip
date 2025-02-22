// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

uint256 constant BASE_FEE = 0.10 * 10 ** 18;
uint256 constant TAX_RATE = 3;
address constant BASE_SEPOLIA_MULTISIG_SAFE= 0x79405092c220FF3fb9DEA28Ca9F56DB8427CEB5e;
address constant BASE_SEPOLIA_MULTISIG_SAFE_OWNER= 0xDe43d4FaAC1e6F0d6484215dfEEA1270a5A3A9be;
address constant ETH_SEPOLIA_MULTISIG_SAFE= 0x79405092c220FF3fb9DEA28Ca9F56DB8427CEB5e;
address constant ETH_SEPOLIA_MULTISIG_SAFE_OWNER= 0xDe43d4FaAC1e6F0d6484215dfEEA1270a5A3A9be;
address constant POLYGON_SEPOLIA_MULTISIG_SAFE= 0x79405092c220FF3fb9DEA28Ca9F56DB8427CEB5e;
address constant POLYGON_SEPOLIA_MULTISIG_SAFE_OWNER= 0xDe43d4FaAC1e6F0d6484215dfEEA1270a5A3A9be;
address constant ARBITRUM_SEPOLIA_MULTISIG_SAFE= 0x79405092c220FF3fb9DEA28Ca9F56DB8427CEB5e;
address constant ARBITRUM_SEPOLIA_MULTISIG_SAFE_OWNER= 0xDe43d4FaAC1e6F0d6484215dfEEA1270a5A3A9be;
bytes constant FOUNDERS= abi.encodePacked(0xDe43d4FaAC1e6F0d6484215dfEEA1270a5A3A9be, 0xDe43d4FaAC1e6F0d6484215dfEEA1270a5A3A9be);
address constant VERIFYING_CONTRACT= 0x0000000000000000000000000000000000000000;
bytes constant DOMAIN_SEPARATOR_SEPOLIA = abi.encodePacked(keccak256(abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)", "degen4life", "1", uint256(11155111), VERIFYING_CONTRACT)));
bytes constant BRIDGE_TYPEHASH_SEPOLIA = abi.encodePacked(keccak256(abi.encodePacked("Bridge(address to,uint256 amount,uint256 nonce,uint256 targetChainId)")));
bytes constant DOMAIN_SEPARATOR_BASE = abi.encodePacked(keccak256(abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)", "degen4life", "1", uint256(84532), VERIFYING_CONTRACT)));
bytes constant BRIDGE_TYPEHASH_BASE = abi.encodePacked(keccak256(abi.encodePacked("Bridge(address to,uint256 amount,uint256 nonce,uint256 targetChainId)")));
bytes constant DOMAIN_SEPARATOR_POLYGON = abi.encodePacked(keccak256(abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)", "degen4life", "1", uint256(1377421055), VERIFYING_CONTRACT)));
bytes constant BRIDGE_TYPEHASH_POLYGON = abi.encodePacked(keccak256(abi.encodePacked("Bridge(address to,uint256 amount,uint256 nonce,uint256 targetChainId)")));
bytes constant DOMAIN_SEPARATOR_ARBITRUM = abi.encodePacked(keccak256(abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)", "degen4life", "1", uint256(421611), VERIFYING_CONTRACT)));
bytes constant BRIDGE_TYPEHASH_ARBITRUM = abi.encodePacked(keccak256(abi.encodePacked("Bridge(address to,uint256 amount,uint256 nonce,uint256 targetChainId)")));
bytes constant DOMAIN_SEPARATOR_BASE_SEPOLIA = abi.encodePacked(keccak256(abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)", "degen4life", "1", uint256(84532), VERIFYING_CONTRACT)));
string constant PLATFORM_NAME= "degen4life";
string constant PLATFORM_VERSION= "1";
uint256 constant CHAIN_ID_BASE= 84532;
uint256 constant CHAIN_ID_BASE_SEPOLIA= 84532;
uint256 constant CHAIN_ID_POLYGON= 1377421055;
uint256 constant CHAIN_ID_ARBITRUM= 421611;
uint256 constant CHAIN_ID_ETH_SEPOLIA= 11155111;
uint256 constant CHAIN_ID_POLYGON_SEPOLIA= 1442;
uint256 constant CHAIN_ID_ARBITRUM_SEPOLIA= 421613;
    // Pool status flags
    uint8 constant POOL_STATUS_ACTIVE = 0x01;
    uint8 constant POOL_STATUS_FROZEN = 0x02;
    uint8 constant POOL_STATUS_DEPRECATED = 0x04;
