// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IContractRegistry {
    function getContractAddressByName(string memory name) external view returns (address);
    function getContractAddressByKey(bytes32 key) external view returns (address);
} 