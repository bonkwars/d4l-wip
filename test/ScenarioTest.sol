// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/Degen4LifeController.sol";
import "../contracts/security/AntiBot.sol";
import "../contracts/security/AntiRugPull.sol";
import "../contracts/modules/SecurityModule.sol";
import "../contracts/modules/LiquidityModule.sol";
import "../contracts/modules/D4LSocialModule.sol";
import "../contracts/modules/SocialTradingModule.sol";
import "../contracts/mocks/MockERC20.sol";
import "../contracts/mocks/MockTokenComponentFactory.sol";
import "./fixtures/D4LFixture.sol";

contract ScenarioTest is Test {
    Degen4LifeController public controller;
    ContractRegistry public registry;
    AntiBot public antiBot;
    AntiRugPull public antiRugPull;
    SecurityModule public securityModule;
    LiquidityModule public liquidityModule;
    D4LSocialModule public socialModule;
    SocialTradingModule public socialTradingModule;
    MockDEX public dex;
    MockENS public ens;
    MockERC20 public weth;
    MockTokenComponentFactory public componentFactory;

    // Test addresses
    address public owner;
    address public tokenCreator;
    address public trader1;
    address public trader2;
    address public liquidityProvider;
    address public botOperator;

    // Constants
    uint256 constant INITIAL_BALANCE = 10_000 ether;
    uint256 constant LIQUIDITY_AMOUNT = 1_000 ether;
    uint256 constant TRADE_AMOUNT = 100 ether;

    function setUp() public {
        // Setup test addresses
        owner = makeAddr("owner");
        tokenCreator = makeAddr("tokenCreator");
        trader1 = makeAddr("trader1");
        trader2 = makeAddr("trader2");
        liquidityProvider = makeAddr("liquidityProvider");
        botOperator = makeAddr("botOperator");

        // Deploy core system using fixture
        D4LFixture fixture = new D4LFixture();
        D4LDeployment memory d = fixture.deployD4L(owner, false);
        
        // Set contract references
        controller = d.controller;
        registry = d.registry;
        antiBot = AntiBot(address(d.antiBot));
        antiRugPull = AntiRugPull(address(d.antiRugPull));
        dex = d.dex;
        ens = d.ens;
        weth = new MockERC20("Wrapped ETH", "WETH", 1_000_000 ether);

        // Deploy and set component factory
        componentFactory = new MockTokenComponentFactory();
        
        // Grant roles and initialize
        vm.startPrank(owner);
        bytes32 defaultAdminRole = 0x00;
        controller.grantRole(defaultAdminRole, owner);
        controller.grantRole(keccak256("POOL_MANAGER"), owner);
        
        // Set component factory
        controller.setComponentFactory(address(componentFactory));
        
        // Initialize modules
        controller.initializeModules(
            address(antiBot),
            address(antiRugPull),
            address(d.socialModule),
            address(d.poolController),
            address(d.dex),
            address(d.ens),
            address(d.predictionMarket)
        );
        vm.stopPrank();

        // Setup initial balances
        vm.deal(tokenCreator, INITIAL_BALANCE);
        vm.deal(trader1, INITIAL_BALANCE);
        vm.deal(trader2, INITIAL_BALANCE);
        vm.deal(liquidityProvider, INITIAL_BALANCE);
        vm.deal(botOperator, INITIAL_BALANCE);

        // Setup WETH balances
        weth.transfer(trader1, INITIAL_BALANCE);
        weth.transfer(trader2, INITIAL_BALANCE);
        weth.transfer(liquidityProvider, INITIAL_BALANCE);
        weth.transfer(botOperator, INITIAL_BALANCE);
    }

    function test_Scenario_TokenLaunchAndTrading() public {
        // 1. Token Creator launches a new token
        vm.startPrank(tokenCreator);
        
        // Create token with security features
        ISecurityModule.SecurityConfig memory securityConfig = ISecurityModule.SecurityConfig({
            maxTransactionAmount: INITIAL_BALANCE / 100,
            timeWindow: 1 hours,
            maxTransactionsPerWindow: 10,
            lockDuration: 7 days,
            minLiquidityPercentage: 500, // 5%
            maxSellPercentage: 1000 // 10%
        });

        ILiquidityModule.PoolParameters memory poolParams = ILiquidityModule.PoolParameters({
            initialLiquidity: LIQUIDITY_AMOUNT,
            minLiquidity: LIQUIDITY_AMOUNT / 2,
            maxLiquidity: LIQUIDITY_AMOUNT * 10,
            lockDuration: 7 days,
            swapFee: 300, // 3%
            autoLiquidity: true
        });

        ISocialModule.TokenGateConfig memory gateConfig = ISocialModule.TokenGateConfig({
            minHoldAmount: LIQUIDITY_AMOUNT / 100,
            minHoldDuration: 1 days,
            requiredLevel: 1,
            requireVerification: false,
            enableTrading: true,
            enableStaking: true
        });

        address newToken = controller.launchToken{value: LIQUIDITY_AMOUNT}(
            "Test Token",
            "TEST",
            INITIAL_BALANCE,
            securityConfig,
            poolParams,
            gateConfig
        );
        vm.stopPrank();

        // 2. Traders interact with the token
        vm.startPrank(trader1);
        MockERC20(newToken).approve(address(dex), type(uint256).max);
        
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = newToken;

        dex.swapExactTokensForTokens(
            TRADE_AMOUNT,
            0,
            path,
            trader1,
            block.timestamp + 1
        );
        vm.stopPrank();

        // 3. Check anti-bot protection
        vm.startPrank(botOperator);
        vm.expectRevert(); // Should revert due to anti-bot protection
        dex.swapExactTokensForTokens(
            TRADE_AMOUNT * 10,
            0,
            path,
            botOperator,
            block.timestamp + 1
        );
        vm.stopPrank();

        // 4. Add more liquidity
        vm.startPrank(liquidityProvider);
        MockERC20(newToken).approve(address(dex), type(uint256).max);
        dex.addLiquidity(
            newToken,
            address(weth),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            liquidityProvider,
            block.timestamp + 1
        );
        vm.stopPrank();

        // Assertions
        assertTrue(MockERC20(newToken).balanceOf(trader1) > 0, "Trader1 should have tokens");
        assertTrue(MockERC20(newToken).balanceOf(address(dex)) > LIQUIDITY_AMOUNT, "DEX should have liquidity");
    }

    function test_Scenario_ENSIntegration() public {
        // 1. Register an ENS name
        string memory name = "trading.d4l";
        
        vm.startPrank(trader1);
        vm.deal(trader1, 1 ether);
        bytes32 nameHash = ens.register{value: 0.1 ether}(name);
        
        // 2. Set up resolver
        ens.setResolver(nameHash, trader1);
        vm.stopPrank();

        // 3. Try to register same name
        vm.startPrank(trader2);
        vm.deal(trader2, 1 ether);
        vm.expectRevert("Name taken");
        ens.register{value: 0.1 ether}(name);
        vm.stopPrank();

        // 4. Fast forward and test expiry
        skip(366 days);
        
        // 5. Original owner can't transfer expired name
        vm.startPrank(trader1);
        vm.expectRevert("Name expired");
        ens.transfer(nameHash, trader2);
        vm.stopPrank();

        // 6. New registration possible after expiry
        vm.startPrank(trader2);
        bytes32 newNameHash = ens.register{value: 0.1 ether}(name);
        assertEq(ens.getOwner(newNameHash), trader2, "Trader2 should own the name after expiry");
        vm.stopPrank();
    }

    function test_Scenario_SecurityAndLiquidity() public {
        // 1. Launch token with strict security settings
        vm.startPrank(tokenCreator);
        
        ISecurityModule.SecurityConfig memory securityConfig = ISecurityModule.SecurityConfig({
            maxTransactionAmount: INITIAL_BALANCE / 200,
            timeWindow: 30 minutes,
            maxTransactionsPerWindow: 5,
            lockDuration: 30 days,
            minLiquidityPercentage: 1000, // 10%
            maxSellPercentage: 500 // 5%
        });

        ILiquidityModule.PoolParameters memory poolParams = ILiquidityModule.PoolParameters({
            initialLiquidity: LIQUIDITY_AMOUNT,
            minLiquidity: LIQUIDITY_AMOUNT / 2,
            maxLiquidity: LIQUIDITY_AMOUNT * 5,
            lockDuration: 30 days,
            swapFee: 300, // 3%
            autoLiquidity: true
        });

        ISocialModule.TokenGateConfig memory gateConfig = ISocialModule.TokenGateConfig({
            minHoldAmount: LIQUIDITY_AMOUNT / 50,
            minHoldDuration: 7 days,
            requiredLevel: 2,
            requireVerification: true,
            enableTrading: true,
            enableStaking: true
        });

        address secureToken = controller.launchToken{value: LIQUIDITY_AMOUNT}(
            "Secure Token",
            "SECURE",
            INITIAL_BALANCE,
            securityConfig,
            poolParams,
            gateConfig
        );
        vm.stopPrank();

        // 2. Test security limits
        vm.startPrank(trader1);
        MockERC20(secureToken).approve(address(dex), type(uint256).max);
        
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = secureToken;

        // Should succeed (within limits)
        dex.swapExactTokensForTokens(
            TRADE_AMOUNT / 10,
            0,
            path,
            trader1,
            block.timestamp + 1
        );

        // Should fail (exceeds max transaction amount)
        vm.expectRevert();
        dex.swapExactTokensForTokens(
            TRADE_AMOUNT * 2,
            0,
            path,
            trader1,
            block.timestamp + 1
        );
        vm.stopPrank();

        // 3. Test liquidity lock
        vm.startPrank(liquidityProvider);
        MockERC20(secureToken).approve(address(dex), type(uint256).max);
        
        // Add liquidity
        (uint256 amount0, uint256 amount1,) = dex.addLiquidity(
            secureToken,
            address(weth),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            liquidityProvider,
            block.timestamp + 1
        );

        // Try to remove liquidity before lock period
        vm.expectRevert();
        dex.removeLiquidity(
            secureToken,
            address(weth),
            amount0,
            0,
            0,
            liquidityProvider,
            block.timestamp + 1
        );

        // Fast forward past lock period
        skip(31 days);

        // Should succeed now
        dex.removeLiquidity(
            secureToken,
            address(weth),
            amount0,
            0,
            0,
            liquidityProvider,
            block.timestamp + 1
        );
        vm.stopPrank();
    }
} 