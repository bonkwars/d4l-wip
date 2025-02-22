// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenomics {
    // Events
    event TaxDistributed(
        uint256 amount,
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexAmount,
        uint256 treasuryAmount,
        uint256 marketingAmount,
        uint256 cexAmount
    );

    function calculateTax(uint256 amount) external pure returns (uint256);
    function calculateBurn(uint256 amount) external pure returns (uint256);
    function calculateCommunityWallet(uint256 amount) external pure returns (uint256);
    function calculateTeamWallet(uint256 amount) external pure returns (uint256);
    function calculateDEXLiquidity(uint256 amount) external pure returns (uint256);
    function calculateTreasuryInitiative(uint256 amount) external pure returns (uint256);
    function calculateMarketingWallet(uint256 amount) external pure returns (uint256);
    function calculateCEXLiquidity(uint256 amount) external pure returns (uint256);
    function calculateTotal(uint256 amount) external pure returns (uint256);
    function calculateTotalFees(uint256 amount) external pure returns (uint256);
    function distributeFees(uint256 amount) external;
} 