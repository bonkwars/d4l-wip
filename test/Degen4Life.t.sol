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
import "./fixtures/D4LFixture.sol";

contract Degen4LifeTest is Test {
    Degen4LifeController public controller;
    ContractRegistry public registry;
    AntiBot public antiBot;
    AntiRugPull public antiRugPull;
    SecurityModule public securityModule;
    LiquidityModule public liquidityModule;
    D4LSocialModule public socialModule;
    SocialTradingModule public socialTradingModule;
    MockERC20 public token;
    MockERC20 public weth;

    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy core system using fixture
        D4LFixture fixture = new D4LFixture();
        D4LDeployment memory d = fixture.deployD4L(owner, false);
        
        // Set contract references
        controller = d.controller;
        registry = d.registry;
        antiBot = AntiBot(address(d.antiBot));
        antiRugPull = AntiRugPull(address(d.antiRugPull));
        token = new MockERC20("Test Token", "TEST", 1_000_000 ether);
        weth = new MockERC20("Wrapped ETH", "WETH", 1_000_000 ether);

        // Grant roles
        vm.startPrank(owner);
        bytes32 defaultAdminRole = 0x00;
        controller.grantRole(defaultAdminRole, owner);
        
        // Initialize modules
        controller.initializeModules(
            address(antiBot),
            address(antiRugPull),
            address(d.userProfile),
            address(d.poolController),
            address(d.dex),
            address(d.ens),
            address(d.predictionMarket)
        );
        vm.stopPrank();

        // Setup initial balances
        token.transfer(user1, 1000 ether);
        token.transfer(user2, 1000 ether);
        weth.transfer(user1, 1000 ether);
        weth.transfer(user2, 1000 ether);

        vm.deal(owner, 1000 ether);
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
    }

    function test_InitialSetup() public {
        assertEq(address(controller.registry()), address(registry));
        assertEq(address(registry.getContractAddress(keccak256("ANTI_BOT"))), address(antiBot));
        assertEq(address(registry.getContractAddress(keccak256("ANTI_RUGPULL"))), address(antiRugPull));
    }
} 