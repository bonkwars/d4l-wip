// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/ITokenomics.sol";

contract TokenomicsRules is Initializable, OwnableUpgradeable, ITokenomics {
    // The following functions are used to define the tokenomics rules for the Degen4Life token.
    // The Degen4Life token is a deflationary token with a 1% burn rate on every transaction.
    // The Degen4Life token has a maximum supply of 1,000,000,000 tokens.
    // The Degen4Life token has a 3% tax on every transaction, which is distributed as follows:
    // The Degen4Life token has a 25% that is added to the community wallet.
    // The Degen4Life token has a 20% that is added to the team wallet.
    // The Degen4Life token has a 30% that is added to the DEX Liquidity pool
    // The Degen4Life token has a 10% that is added to the Degen4Life treasury initiative.
    // The Degen4Life token has a 10% that is added to the marketing wallet.
    // The Degen4Life token has a 5% that is added to the CEX Liquidity.

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;
    uint256 public constant BURN_RATE = 1;
    uint256 public constant TAX_RATE = 3;
    uint256 public constant COMMUNITY_WALLET_RATE = 25;
    uint256 public constant TEAM_WALLET_RATE = 20;
    uint256 public constant DEX_LIQUIDITY_RATE = 30;
    uint256 public constant TREASURY_INITIATIVE_RATE = 10;
    uint256 public constant MARKETING_WALLET_RATE = 10;
    uint256 public constant CEX_LIQUIDITY_RATE = 5;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    // The following functions are used to calculate the tax amount for a given transaction amount.
    function calculateTax(uint256 amount) public pure override returns (uint256) {
        return (amount * TAX_RATE) / 100;
    }

    // The following functions are used to calculate the burn amount for a given transaction amount.
    function calculateBurn(uint256 amount) public pure override returns (uint256) {
        return (amount * BURN_RATE) / 100;
    }

    // The following functions are used to calculate the community wallet amount for a given transaction amount.
    function calculateCommunityWallet(uint256 amount) public pure override returns (uint256) {
        return (amount * COMMUNITY_WALLET_RATE) / 100;
    }

    // The following functions are used to calculate the team wallet amount for a given transaction amount.
    function calculateTeamWallet(uint256 amount) public pure override returns (uint256) {
        return (amount * TEAM_WALLET_RATE) / 100;
    }

    // The following functions are used to calculate the DEX liquidity pool amount for a given transaction amount
    function calculateDEXLiquidity(uint256 amount) public pure override returns (uint256) {
        return (amount * DEX_LIQUIDITY_RATE) / 100;
    }

    // The following functions are used to calculate the treasury initiative amount for a given transaction amount
    function calculateTreasuryInitiative(uint256 amount) public pure override returns (uint256) {
        return (amount * TREASURY_INITIATIVE_RATE) / 100;
    }

    // The following functions are used to calculate the marketing wallet amount for a given transaction amount
    function calculateMarketingWallet(uint256 amount) public pure override returns (uint256) {
        return (amount * MARKETING_WALLET_RATE) / 100;
    }

    // The following functions are used to calculate the CEX liquidity amount for a given transaction amount
    function calculateCEXLiquidity(uint256 amount) public pure override returns (uint256) {
        return (amount * CEX_LIQUIDITY_RATE) / 100;
    }

    // The following functions are used to calculate the total amount for a given transaction amount
    function calculateTotal(uint256 amount) public pure override returns (uint256) {
        return (amount +
            calculateTax(amount) +
            calculateBurn(amount) +
            calculateCommunityWallet(amount) +
            calculateTeamWallet(amount) +
            calculateDEXLiquidity(amount) +
            calculateTreasuryInitiative(amount) +
            calculateMarketingWallet(amount) +
            calculateCEXLiquidity(amount));
    }

    // The following functions are used to calculate the tax amount for a given transaction amount
    function calculateTotalFees(uint256 amount) public pure override returns (uint256) {
        return calculateTax(amount);
    }

    // Function to distribute fees to various wallets
    function distributeFees(uint256 amount) external override {
        uint256 communityAmount = calculateCommunityWallet(amount);
        uint256 teamAmount = calculateTeamWallet(amount);
        uint256 dexAmount = calculateDEXLiquidity(amount);
        uint256 treasuryAmount = calculateTreasuryInitiative(amount);
        uint256 marketingAmount = calculateMarketingWallet(amount);
        uint256 cexAmount = calculateCEXLiquidity(amount);
        uint256 burnAmount = calculateBurn(amount);

        // Emit event for tracking
        emit TaxDistributed(
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
