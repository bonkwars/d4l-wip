// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/security/AntiBot.sol";
import "../contracts/security/AntiRugPull.sol";
import "../contracts/mocks/MockERC20.sol";
import "./fixtures/D4LFixture.sol";
import "./mocks/SimpleBot.sol";
import "./mocks/SandwichBot.sol";
import "./mocks/SnipingBot.sol";

contract AntiBotAttackTest is Test {
    Degen4LifeController public controller;
    AntiBot public antiBot;
    AntiRugPull public antiRugPull;
    ContractRegistry public registry;
    MockERC20 public token;
    SimpleBot public simpleBot;
    SandwichBot public sandwichBot;
    SnipingBot public snipingBot;

    address public owner;
    address public attacker;
    address public user1;
    address public user2;

    // Constants
    uint256 constant INITIAL_BALANCE = 1_000_000 ether;
    uint256 constant TRADE_AMOUNT = 1000 ether;
    uint256 constant BLOCK_DELAY = 5;
    uint256 constant MAX_WALLET_RATIO = 100; // 1%
    uint256 constant MAX_TX_RATIO = 50; // 0.5%

    // Bot detection parameters
    uint256 constant MIN_BLOCKS_BETWEEN_TXS = 3;
    uint256 constant MAX_TXS_PER_BLOCK = 2;
    uint256 constant SUSPICIOUS_PATTERN_THRESHOLD = 3;

    // Add new constants
    uint256 constant FLASH_LOAN_AMOUNT = 100_000 ether;
    uint256 constant MIN_BLOCKS_FOR_ARBS = 5;
    uint256 constant MAX_CROSS_CHAIN_TXS = 3;

    function setUp() public {
        owner = makeAddr("owner");
        attacker = makeAddr("attacker");
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
        token = new MockERC20("Test Token", "TEST", 0); // Start with 0 supply

        // Deploy bot contracts
        simpleBot = new SimpleBot(address(token));
        sandwichBot = new SandwichBot(address(token));
        snipingBot = new SnipingBot(address(token));

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

        // Setup initial balances by minting
        token.mint(attacker, INITIAL_BALANCE / 8);
        token.mint(user1, INITIAL_BALANCE / 8);
        token.mint(user2, INITIAL_BALANCE / 8);

        // Fund bots
        token.mint(address(simpleBot), INITIAL_BALANCE / 8);
        token.mint(address(sandwichBot), INITIAL_BALANCE / 8);
        token.mint(address(snipingBot), INITIAL_BALANCE / 8);

        vm.deal(attacker, 1000 ether);
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
    }

    function test_SimpleBot() public {
        vm.startPrank(attacker);
        simpleBot.executeSimpleAttack(TRADE_AMOUNT);
        vm.stopPrank();
    }

    function test_SandwichBot() public {
        vm.startPrank(attacker);
        sandwichBot.executeSandwichAttack(TRADE_AMOUNT, user1);
        vm.stopPrank();
    }

    function test_SnipingBot() public {
        address[] memory targets = new address[](2);
        targets[0] = user1;
        targets[1] = user2;

        vm.startPrank(attacker);
        snipingBot.executeSnipingAttack(TRADE_AMOUNT, targets);
        vm.stopPrank();
    }
} 