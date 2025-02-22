// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDegen4LifeController {
    struct SystemAddresses {
        address tokenFactory;
        address poolController;
        address feeHandler;
    }
}

interface IDegen4LifeDAO {
    function proposeParameterChange(
        address target,
        bytes32 parameter,
        uint256 newValue
    ) external returns (uint256);
} 