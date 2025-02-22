// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/tokenomics/tokenomics.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TokenomicsRulesTest is Test {
    TokenomicsRules public implementation;
    TokenomicsRules public tokenomics;
    address public owner;
    address public user1;
    address public user2;

    event TaxDistributed(
        uint256 amount,
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexAmount,
        uint256 treasuryAmount,
        uint256 marketingAmount,
        uint256 cexAmount
    );

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy implementation
        implementation = new TokenomicsRules();
        
        // Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            TokenomicsRules.initialize.selector,
            owner
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        // Get tokenomics instance
        tokenomics = TokenomicsRules(address(proxy));
    }

    function test_InitialSetup() public view {
        assertEq(tokenomics.owner(), owner);
        assertEq(tokenomics.MAX_SUPPLY(), 1_000_000_000 * 10 ** 18);
        assertEq(tokenomics.BURN_RATE(), 1);
        assertEq(tokenomics.TAX_RATE(), 3);
        assertEq(tokenomics.COMMUNITY_WALLET_RATE(), 25);
        assertEq(tokenomics.TEAM_WALLET_RATE(), 20);
        assertEq(tokenomics.DEX_LIQUIDITY_RATE(), 30);
        assertEq(tokenomics.TREASURY_INITIATIVE_RATE(), 10);
        assertEq(tokenomics.MARKETING_WALLET_RATE(), 10);
        assertEq(tokenomics.CEX_LIQUIDITY_RATE(), 5);
    }

    function test_CalculateTax() public view {
        uint256 amount = 1000e18;
        uint256 expectedTax = (amount * tokenomics.TAX_RATE()) / 100;
        assertEq(tokenomics.calculateTax(amount), expectedTax);
    }

    function test_CalculateBurn() public view {
        uint256 amount = 1000e18;
        uint256 expectedBurn = (amount * tokenomics.BURN_RATE()) / 100;
        assertEq(tokenomics.calculateBurn(amount), expectedBurn);
    }

    function test_CalculateCommunityWallet() public view {
        uint256 amount = 1000e18;
        uint256 expected = (amount * tokenomics.COMMUNITY_WALLET_RATE()) / 100;
        assertEq(tokenomics.calculateCommunityWallet(amount), expected);
    }

    function test_CalculateTeamWallet() public view {
        uint256 amount = 1000e18;
        uint256 expected = (amount * tokenomics.TEAM_WALLET_RATE()) / 100;
        assertEq(tokenomics.calculateTeamWallet(amount), expected);
    }

    function test_CalculateDEXLiquidity() public view {
        uint256 amount = 1000e18;
        uint256 expected = (amount * tokenomics.DEX_LIQUIDITY_RATE()) / 100;
        assertEq(tokenomics.calculateDEXLiquidity(amount), expected);
    }

    function test_CalculateTreasuryInitiative() public view {
        uint256 amount = 1000e18;
        uint256 expected = (amount * tokenomics.TREASURY_INITIATIVE_RATE()) / 100;
        assertEq(tokenomics.calculateTreasuryInitiative(amount), expected);
    }

    function test_CalculateMarketingWallet() public view {
        uint256 amount = 1000e18;
        uint256 expected = (amount * tokenomics.MARKETING_WALLET_RATE()) / 100;
        assertEq(tokenomics.calculateMarketingWallet(amount), expected);
    }

    function test_CalculateCEXLiquidity() public view {
        uint256 amount = 1000e18;
        uint256 expected = (amount * tokenomics.CEX_LIQUIDITY_RATE()) / 100;
        assertEq(tokenomics.calculateCEXLiquidity(amount), expected);
    }

    function test_CalculateTotal() public view {
        uint256 amount = 1000e18;
        uint256 expected = amount +
            tokenomics.calculateTax(amount) +
            tokenomics.calculateBurn(amount) +
            tokenomics.calculateCommunityWallet(amount) +
            tokenomics.calculateTeamWallet(amount) +
            tokenomics.calculateDEXLiquidity(amount) +
            tokenomics.calculateTreasuryInitiative(amount) +
            tokenomics.calculateMarketingWallet(amount) +
            tokenomics.calculateCEXLiquidity(amount);
        assertEq(tokenomics.calculateTotal(amount), expected);
    }

    function test_DistributeFees() public {
        uint256 amount = 1000e18;
        
        vm.expectEmit(true, true, true, true);
        emit TaxDistributed(
            amount,
            tokenomics.calculateCommunityWallet(amount),
            tokenomics.calculateTeamWallet(amount),
            tokenomics.calculateDEXLiquidity(amount),
            tokenomics.calculateTreasuryInitiative(amount),
            tokenomics.calculateMarketingWallet(amount),
            tokenomics.calculateCEXLiquidity(amount)
        );

        tokenomics.distributeFees(amount);
    }

    function test_FuzzCalculations(uint256 amount) public view {
        vm.assume(amount > 0 && amount <= tokenomics.MAX_SUPPLY());

        uint256 tax = tokenomics.calculateTax(amount);
        uint256 burn = tokenomics.calculateBurn(amount);
        uint256 community = tokenomics.calculateCommunityWallet(amount);
        uint256 team = tokenomics.calculateTeamWallet(amount);
        uint256 dex = tokenomics.calculateDEXLiquidity(amount);
        uint256 treasury = tokenomics.calculateTreasuryInitiative(amount);
        uint256 marketing = tokenomics.calculateMarketingWallet(amount);
        uint256 cex = tokenomics.calculateCEXLiquidity(amount);

        // Verify tax calculations
        assertEq(tax, (amount * tokenomics.TAX_RATE()) / 100);
        assertEq(burn, (amount * tokenomics.BURN_RATE()) / 100);
        assertEq(community, (amount * tokenomics.COMMUNITY_WALLET_RATE()) / 100);
        assertEq(team, (amount * tokenomics.TEAM_WALLET_RATE()) / 100);
        assertEq(dex, (amount * tokenomics.DEX_LIQUIDITY_RATE()) / 100);
        assertEq(treasury, (amount * tokenomics.TREASURY_INITIATIVE_RATE()) / 100);
        assertEq(marketing, (amount * tokenomics.MARKETING_WALLET_RATE()) / 100);
        assertEq(cex, (amount * tokenomics.CEX_LIQUIDITY_RATE()) / 100);

        // Verify total calculation
        uint256 total = tokenomics.calculateTotal(amount);
        assertEq(total, amount + tax + burn + community + team + dex + treasury + marketing + cex);
    }
} 