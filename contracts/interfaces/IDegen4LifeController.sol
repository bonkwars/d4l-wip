// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDegen4LifeController {
    function proposeParameterChange(
        address target,
        bytes32 parameter,
        uint256 newValue
    ) external returns (uint256);
    
    function getTokenData(address token) external view returns (
        address creator,
        uint256 creationTimestamp,
        bool securityEnabled,
        uint256 socialScore,
        address associatedPool
    );
} 