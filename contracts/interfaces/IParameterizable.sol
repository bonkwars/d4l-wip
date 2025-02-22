// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IParameterizable {
    function updateParameter(bytes32 parameter, uint256 newValue) external;
} 