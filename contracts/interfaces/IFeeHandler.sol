// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFeeHandler {
    function calculateFee(
        address token,
        uint256 amount,
        address user
    ) external view returns (uint256 feeAmount);
    
    function distributeFees(address token) external;
    
    function updateFeeParameters(
        bytes32 parameter,
        uint256 newValue
    ) external;

    function distributeTaxes(
        address token,
        uint256 amount
    ) external;
} 