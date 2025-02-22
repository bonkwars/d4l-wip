// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/ITokenomics.sol";

contract MockTokenomics is ITokenomics {
    uint256 public constant TAX_RATE = 3;
    uint256 public constant BURN_RATE = 1;
    uint256 public constant COMMUNITY_RATE = 25;
    uint256 public constant TEAM_RATE = 20;
    uint256 public constant DEX_RATE = 30;
    uint256 public constant TREASURY_RATE = 10;
    uint256 public constant MARKETING_RATE = 10;
    uint256 public constant CEX_RATE = 5;

    event FeesDistributed(
        uint256 amount,
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexAmount,
        uint256 treasuryAmount,
        uint256 marketingAmount,
        uint256 cexAmount
    );

    function calculateTax(uint256 amount) external pure returns (uint256) {
        return (amount * TAX_RATE) / 100;
    }

    function calculateBurn(uint256 amount) external pure returns (uint256) {
        return (amount * BURN_RATE) / 100;
    }

    function calculateCommunityWallet(uint256 amount) external pure returns (uint256) {
        return (amount * COMMUNITY_RATE) / 100;
    }

    function calculateTeamWallet(uint256 amount) external pure returns (uint256) {
        return (amount * TEAM_RATE) / 100;
    }

    function calculateDEXLiquidity(uint256 amount) external pure returns (uint256) {
        return (amount * DEX_RATE) / 100;
    }

    function calculateTreasuryInitiative(uint256 amount) external pure returns (uint256) {
        return (amount * TREASURY_RATE) / 100;
    }

    function calculateMarketingWallet(uint256 amount) external pure returns (uint256) {
        return (amount * MARKETING_RATE) / 100;
    }

    function calculateCEXLiquidity(uint256 amount) external pure returns (uint256) {
        return (amount * CEX_RATE) / 100;
    }

    function calculateTotal(uint256 amount) external pure returns (uint256) {
        return amount + calculateTotalFees(amount);
    }

    function calculateTotalFees(uint256 amount) public pure returns (uint256) {
        return (amount * TAX_RATE) / 100;
    }

    function distributeFees(uint256 amount) external {
        uint256 communityAmount = (amount * COMMUNITY_RATE) / 100;
        uint256 teamAmount = (amount * TEAM_RATE) / 100;
        uint256 dexAmount = (amount * DEX_RATE) / 100;
        uint256 treasuryAmount = (amount * TREASURY_RATE) / 100;
        uint256 marketingAmount = (amount * MARKETING_RATE) / 100;
        uint256 cexAmount = (amount * CEX_RATE) / 100;

        emit FeesDistributed(
            amount,
            communityAmount,
            teamAmount,
            dexAmount,
            treasuryAmount,
            marketingAmount,
            cexAmount
        );
    }
} 