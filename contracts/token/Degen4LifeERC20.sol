// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "../tokenomics/tokenomics.sol";
import "./MultiChainToken.sol";

contract Degen4LifeToken is MultiChainToken {
    // Tokenomics
    TokenomicsRules public immutable tokenomics;
    
    // Wallets
    address public communityWallet;
    address public teamWallet;
    address public dexLiquidityWallet;
    address public treasuryWallet;
    address public marketingWallet;
    address public cexLiquidityWallet;
    
    // Fee exclusions
    mapping(address => bool) public isExcludedFromFees;
    
    // Events
    event WalletUpdated(string walletType, address newWallet);
    event FeeDistributed(
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexLiquidityAmount,
        uint256 treasuryAmount,
        uint256 marketingAmount,
        uint256 cexLiquidityAmount,
        uint256 burnAmount
    );

    constructor(
        address _tokenomics,
        address _communityWallet,
        address _teamWallet,
        address _dexLiquidityWallet,
        address _treasuryWallet,
        address _marketingWallet,
        address _cexLiquidityWallet,
        address trustedForwarder,
        uint256 initialSupply
    ) MultiChainToken(
        "Degen4Life",
        "DE4L",
        block.chainid,
        trustedForwarder
    ) {
        tokenomics = TokenomicsRules(_tokenomics);
        
        communityWallet = _communityWallet;
        teamWallet = _teamWallet;
        dexLiquidityWallet = _dexLiquidityWallet;
        treasuryWallet = _treasuryWallet;
        marketingWallet = _marketingWallet;
        cexLiquidityWallet = _cexLiquidityWallet;
        
        // Exclude fee wallets from fees
        isExcludedFromFees[_communityWallet] = true;
        isExcludedFromFees[_teamWallet] = true;
        isExcludedFromFees[_dexLiquidityWallet] = true;
        isExcludedFromFees[_treasuryWallet] = true;
        isExcludedFromFees[_marketingWallet] = true;
        isExcludedFromFees[_cexLiquidityWallet] = true;
        
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    function _update(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (sender == address(0) || recipient == address(0) || 
            isExcludedFromFees[sender] || isExcludedFromFees[recipient]) {
            super._update(sender, recipient, amount);
            return;
        }

        // Calculate fees
        uint256 burnAmount = tokenomics.calculateBurn(amount);
        uint256 communityAmount = tokenomics.calculateCommunityWallet(amount);
        uint256 teamAmount = tokenomics.calculateTeamWallet(amount);
        uint256 dexLiquidityAmount = tokenomics.calculateDEXLiquidity(amount);
        uint256 treasuryAmount = tokenomics.calculateTreasuryInitiative(amount);
        uint256 marketingAmount = tokenomics.calculateMarketingWallet(amount);
        uint256 cexLiquidityAmount = tokenomics.calculateCEXLiquidity(amount);

        // Calculate net transfer amount
        uint256 totalFees = burnAmount + communityAmount + teamAmount + 
            dexLiquidityAmount + treasuryAmount + marketingAmount + cexLiquidityAmount;
        uint256 netAmount = amount - totalFees;

        // Execute transfers
        _burn(sender, burnAmount);
        super._update(sender, communityWallet, communityAmount);
        super._update(sender, teamWallet, teamAmount);
        super._update(sender, dexLiquidityWallet, dexLiquidityAmount);
        super._update(sender, treasuryWallet, treasuryAmount);
        super._update(sender, marketingWallet, marketingAmount);
        super._update(sender, cexLiquidityWallet, cexLiquidityAmount);
        super._update(sender, recipient, netAmount);

        emit FeeDistributed(
            communityAmount,
            teamAmount,
            dexLiquidityAmount,
            treasuryAmount,
            marketingAmount,
            cexLiquidityAmount,
            burnAmount
        );
    }

    // Admin functions
    function excludeFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
    }

    function updateWallets(
        address _communityWallet,
        address _teamWallet,
        address _dexLiquidityWallet,
        address _treasuryWallet,
        address _marketingWallet,
        address _cexLiquidityWallet
    ) external onlyOwner {
        require(_communityWallet != address(0) &&
                _teamWallet != address(0) &&
                _dexLiquidityWallet != address(0) &&
                _treasuryWallet != address(0) &&
                _marketingWallet != address(0) &&
                _cexLiquidityWallet != address(0), "Zero address");

        communityWallet = _communityWallet;
        teamWallet = _teamWallet;
        dexLiquidityWallet = _dexLiquidityWallet;
        treasuryWallet = _treasuryWallet;
        marketingWallet = _marketingWallet;
        cexLiquidityWallet = _cexLiquidityWallet;

        // Update fee exclusions
        isExcludedFromFees[_communityWallet] = true;
        isExcludedFromFees[_teamWallet] = true;
        isExcludedFromFees[_dexLiquidityWallet] = true;
        isExcludedFromFees[_treasuryWallet] = true;
        isExcludedFromFees[_marketingWallet] = true;
        isExcludedFromFees[_cexLiquidityWallet] = true;
    }
}