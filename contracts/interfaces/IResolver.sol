// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IResolver {
    function resolve(address tokenAddress) external view returns (string memory);
} 