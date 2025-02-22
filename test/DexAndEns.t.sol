// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/Degen4LifeController.sol";
import "../contracts/interfaces/IDegenDEX.sol";
import "../contracts/interfaces/IDegenENS.sol";
import "../contracts/registry/ContractRegistry.sol";
import "../contracts/mocks/MockERC20.sol";
import "../contracts/mocks/MockDEX.sol";
import "../contracts/mocks/MockENS.sol";
import "./fixtures/D4LFixture.sol";

contract DexAndEnsTest is Test {
    Degen4LifeController public controller;
    MockDEX public dex;
    MockENS public ens;
    ContractRegistry public registry;
    MockERC20 public token0;
    MockERC20 public token1;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public attacker;

    // Constants for testing
    uint256 constant INITIAL_LIQUIDITY = 1000 ether;
    uint256 constant SWAP_AMOUNT = 10 ether;
    uint256 constant FEE = 3000; // 0.3%
    uint256 constant MIN_AMOUNT = 990 ether; // 99% of initial amount

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        attacker = makeAddr("attacker");

        // Deploy core system using fixture
        D4LFixture fixture = new D4LFixture();
        D4LDeployment memory d = fixture.deployD4L(owner, false);
        
        // Set contract references
        controller = d.controller;
        dex = d.dex;
        ens = d.ens;
        registry = d.registry;

        // Deploy test tokens
        token0 = new MockERC20("Token0", "TK0", 1_000_000 ether);
        token1 = new MockERC20("Token1", "TK1", 1_000_000 ether);

        // Setup initial balances
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(attacker, 100 ether);

        token0.transfer(user1, 10_000 ether);
        token0.transfer(user2, 10_000 ether);
        token0.transfer(user3, 10_000 ether);
        token0.transfer(attacker, 10_000 ether);

        token1.transfer(user1, 10_000 ether);
        token1.transfer(user2, 10_000 ether);
        token1.transfer(user3, 10_000 ether);
        token1.transfer(attacker, 10_000 ether);

        // Approve tokens
        vm.startPrank(user1);
        token0.approve(address(dex), type(uint256).max);
        token1.approve(address(dex), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        token0.approve(address(dex), type(uint256).max);
        token1.approve(address(dex), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        token0.approve(address(dex), type(uint256).max);
        token1.approve(address(dex), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(attacker);
        token0.approve(address(dex), type(uint256).max);
        token1.approve(address(dex), type(uint256).max);
        vm.stopPrank();
    }

    // DEX Tests

    function test_CreatePool() public {
        vm.startPrank(owner);
        address pool = dex.createPool(
            address(token0),
            address(token1),
            FEE
        );
        vm.stopPrank();

        assertTrue(pool != address(0), "Pool not created");
        
        MockDEX.Pool memory poolInfo = dex.getPool(address(token0), address(token1));
        assertEq(poolInfo.fee, FEE, "Wrong fee");
        assertEq(poolInfo.reserve0, 0, "Non-zero initial reserve0");
        assertEq(poolInfo.reserve1, 0, "Non-zero initial reserve1");
    }

    function test_RevertCreatePoolWithSameTokens() public {
        vm.startPrank(owner);
        vm.expectRevert("Identical tokens");
        dex.createPool(address(token0), address(token0), FEE);
        vm.stopPrank();
    }

    function test_RevertCreatePoolWithHighFee() public {
        vm.startPrank(owner);
        vm.expectRevert("Fee too high");
        dex.createPool(address(token0), address(token1), 20000); // 200%
        vm.stopPrank();
    }

    function test_RevertCreateDuplicatePool() public {
        vm.startPrank(owner);
        dex.createPool(address(token0), address(token1), FEE);
        vm.expectRevert("Pool exists");
        dex.createPool(address(token0), address(token1), FEE);
        vm.stopPrank();
    }

    function test_AddLiquidity() public {
        vm.prank(owner);
        dex.createPool(address(token0), address(token1), FEE);

        vm.startPrank(user1);
        (uint256 amount0, uint256 amount1, uint256 liquidity) = dex.addLiquidity(
            address(token0),
            address(token1),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            MIN_AMOUNT,
            MIN_AMOUNT,
            user1,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(amount0, 0, "No token0 added");
        assertGt(amount1, 0, "No token1 added");
        assertGt(liquidity, 0, "No liquidity minted");

        MockDEX.Pool memory pool = dex.getPool(address(token0), address(token1));
        assertEq(pool.reserve0, INITIAL_LIQUIDITY, "Wrong reserve0");
        assertEq(pool.reserve1, INITIAL_LIQUIDITY, "Wrong reserve1");
    }

    function test_RevertAddLiquidityAfterDeadline() public {
        vm.prank(owner);
        dex.createPool(address(token0), address(token1), FEE);

        vm.startPrank(user1);
        vm.expectRevert("Expired");
        dex.addLiquidity(
            address(token0),
            address(token1),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            MIN_AMOUNT,
            MIN_AMOUNT,
            user1,
            block.timestamp - 1
        );
        vm.stopPrank();
    }

    function test_RevertAddLiquidityInsufficientAmount() public {
        vm.prank(owner);
        dex.createPool(address(token0), address(token1), FEE);

        vm.startPrank(user1);
        vm.expectRevert("Insufficient amount0");
        dex.addLiquidity(
            address(token0),
            address(token1),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY + 1,
            MIN_AMOUNT,
            user1,
            block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_Swap() public {
        // Setup pool with liquidity
        vm.prank(owner);
        dex.createPool(address(token0), address(token1), FEE);

        vm.startPrank(user1);
        dex.addLiquidity(
            address(token0),
            address(token1),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            MIN_AMOUNT,
            MIN_AMOUNT,
            user1,
            block.timestamp + 1
        );
        vm.stopPrank();

        // Perform swap
        vm.startPrank(user2);
        uint256 balanceBefore = token1.balanceOf(user2);
        
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);

        uint256[] memory amounts = dex.swapExactTokensForTokens(
            SWAP_AMOUNT,
            0,
            path,
            user2,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(amounts[1], 0, "No tokens received");
        assertEq(token0.balanceOf(user2), 10_000 ether - SWAP_AMOUNT, "Wrong token0 balance");
        assertGt(token1.balanceOf(user2), balanceBefore, "No token1 received");

        // Verify reserves updated
        MockDEX.Pool memory pool = dex.getPool(address(token0), address(token1));
        assertEq(pool.reserve0, INITIAL_LIQUIDITY + SWAP_AMOUNT, "Wrong reserve0 after swap");
        assertLt(pool.reserve1, INITIAL_LIQUIDITY, "Wrong reserve1 after swap");
    }

    function test_GetAmountOut() public {
        vm.prank(owner);
        dex.createPool(address(token0), address(token1), FEE);

        vm.startPrank(user1);
        dex.addLiquidity(
            address(token0),
            address(token1),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            MIN_AMOUNT,
            MIN_AMOUNT,
            user1,
            block.timestamp + 1
        );
        vm.stopPrank();

        uint256 amountOut = dex.getAmountOut(SWAP_AMOUNT, address(token0), address(token1));
        assertGt(amountOut, 0, "Invalid amount out");
        
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        
        uint256[] memory amounts = dex.getAmountsOut(SWAP_AMOUNT, path);
        assertEq(amounts[0], SWAP_AMOUNT, "Wrong input amount");
        assertEq(amounts[1], amountOut, "Inconsistent amount out calculation");
    }

    // ENS Tests

    function test_RegisterENSName() public {
        string memory name = "test.d4l";

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        bytes32 nameHash = ens.register{value: 0.1 ether}(name);
        vm.stopPrank();

        assertEq(ens.getOwner(nameHash), user1, "Wrong name owner");
        assertGt(ens.getExpiryDate(nameHash), block.timestamp, "Invalid expiry date");
    }

    function test_RevertRegisterWithInsufficientFee() public {
        string memory name = "test.d4l";

        vm.startPrank(user1);
        vm.deal(user1, 0.05 ether);
        vm.expectRevert("Insufficient fee");
        ens.register{value: 0.05 ether}(name);
        vm.stopPrank();
    }

    function test_RevertRegisterTakenName() public {
        string memory name = "test.d4l";

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        ens.register{value: 0.1 ether}(name);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.deal(user2, 1 ether);
        vm.expectRevert("Name taken");
        ens.register{value: 0.1 ether}(name);
        vm.stopPrank();
    }

    function test_TransferENSName() public {
        string memory name = "test.d4l";
        
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        bytes32 nameHash = ens.register{value: 0.1 ether}(name);

        // Transfer name
        ens.transfer(nameHash, user2);
        vm.stopPrank();

        assertEq(ens.getOwner(nameHash), user2, "Name not transferred");
    }

    function test_RevertUnauthorizedTransfer() public {
        string memory name = "test.d4l";
        
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        bytes32 nameHash = ens.register{value: 0.1 ether}(name);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Not owner");
        ens.transfer(nameHash, user3);
        vm.stopPrank();
    }

    function test_RenewENSName() public {
        string memory name = "test.d4l";
        
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        bytes32 nameHash = ens.register{value: 0.1 ether}(name);

        uint256 expiryBefore = ens.getExpiryDate(nameHash);
        
        // Renew name
        ens.renew{value: 0.1 ether}(nameHash);
        vm.stopPrank();

        uint256 expiryAfter = ens.getExpiryDate(nameHash);
        assertGt(expiryAfter, expiryBefore, "Expiry not extended");
    }

    function test_RevertRenewUnregisteredName() public {
        bytes32 nameHash = keccak256("unregistered.d4l");
        
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        vm.expectRevert("Name not registered");
        ens.renew{value: 0.1 ether}(nameHash);
        vm.stopPrank();
    }

    function test_RevertRenewWithInsufficientFee() public {
        string memory name = "test.d4l";
        
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        bytes32 nameHash = ens.register{value: 0.1 ether}(name);
        
        vm.expectRevert("Insufficient fee");
        ens.renew{value: 0.05 ether}(nameHash);
        vm.stopPrank();
    }

    function test_RevertOnExpiredENSName() public {
        string memory name = "test.d4l";
        
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        bytes32 nameHash = ens.register{value: 0.1 ether}(name);

        // Fast forward past expiration
        skip(367 days);

        vm.expectRevert("Name expired");
        ens.transfer(nameHash, user2);
        vm.stopPrank();
    }

    function test_GetExpiryDate() public {
        string memory name = "test.d4l";
        
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        bytes32 nameHash = ens.register{value: 0.1 ether}(name);
        vm.stopPrank();

        uint256 expiry = ens.getExpiryDate(nameHash);
        assertEq(expiry, block.timestamp + 365 days, "Wrong expiry date");
    }

    // Add attacker tests
    function test_AttackPriceManipulation() public {
        // Setup initial liquidity
        vm.prank(owner);
        dex.createPool(address(token0), address(token1), FEE);

        vm.startPrank(user1);
        dex.addLiquidity(
            address(token0),
            address(token1),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            MIN_AMOUNT,
            MIN_AMOUNT,
            user1,
            block.timestamp + 1
        );
        vm.stopPrank();

        // Attacker tries to manipulate price with large swap
        vm.startPrank(attacker);
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);

        // Large swap to manipulate price
        uint256 largeAmount = INITIAL_LIQUIDITY * 10;
        vm.expectRevert("Insufficient output"); // Should revert due to slippage
        dex.swapExactTokensForTokens(
            largeAmount,
            largeAmount, // Unrealistic minimum output
            path,
            attacker,
            block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_AttackFrontRunning() public {
        // Setup initial liquidity
        vm.prank(owner);
        dex.createPool(address(token0), address(token1), FEE);

        vm.startPrank(user1);
        dex.addLiquidity(
            address(token0),
            address(token1),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            MIN_AMOUNT,
            MIN_AMOUNT,
            user1,
            block.timestamp + 1
        );
        vm.stopPrank();

        // User2 attempts to swap
        vm.startPrank(user2);
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);

        uint256[] memory amounts = dex.swapExactTokensForTokens(
            SWAP_AMOUNT,
            0,
            path,
            user2,
            block.timestamp + 1
        );
        uint256 receivedAmount = amounts[1];
        vm.stopPrank();

        // Attacker tries to front-run with same parameters
        vm.startPrank(attacker);
        amounts = dex.swapExactTokensForTokens(
            SWAP_AMOUNT,
            0,
            path,
            attacker,
            block.timestamp + 1
        );
        vm.stopPrank();

        // Verify attacker got worse rate due to price impact
        assertLt(amounts[1], receivedAmount, "Attacker should get worse rate");
    }

    function test_AttackInfiniteApproval() public {
        vm.prank(owner);
        dex.createPool(address(token0), address(token1), FEE);

        // Attacker tries to exploit infinite approval
        vm.startPrank(attacker);
        token0.approve(address(dex), type(uint256).max);
        
        // Try to add more liquidity than approved
        uint256 hugeAmount = type(uint256).max;
        vm.expectRevert(); // Should revert due to insufficient balance
        dex.addLiquidity(
            address(token0),
            address(token1),
            hugeAmount,
            hugeAmount,
            0,
            0,
            attacker,
            block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_AttackENSExpiry() public {
        string memory name = "valuable.d4l";
        
        // Original owner registers name
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        bytes32 nameHash = ens.register{value: 0.1 ether}(name);
        vm.stopPrank();

        // Fast forward to near expiration
        skip(364 days);

        // Attacker tries to take over name before expiry
        vm.startPrank(attacker);
        vm.deal(attacker, 1 ether);
        vm.expectRevert("Name taken");
        ens.register{value: 0.1 ether}(name);
        vm.stopPrank();

        // Original owner can still renew
        vm.startPrank(user1);
        ens.renew{value: 0.1 ether}(nameHash);
        assertEq(ens.getOwner(nameHash), user1, "Owner should not change");
        vm.stopPrank();

        // Fast forward past expiration without renewal
        skip(366 days);

        // Verify name is expired
        vm.startPrank(user1);
        vm.expectRevert("Name expired");
        ens.transfer(nameHash, user2);
        vm.stopPrank();

        // Now attacker can take the name since it's expired
        vm.startPrank(attacker);
        bytes32 newNameHash = ens.register{value: 0.1 ether}(name);
        assertEq(ens.getOwner(newNameHash), attacker, "Attacker should own expired name");
        vm.stopPrank();
    }

    function test_AttackENSFrontRunning() public {
        string memory name = "rare.d4l";
        uint256 registrationFee = 0.1 ether;

        // Attacker monitors mempool and front-runs registration
        vm.startPrank(attacker);
        vm.deal(attacker, 1 ether);
        bytes32 nameHash = ens.register{value: registrationFee}(name);
        assertEq(ens.getOwner(nameHash), attacker, "Attacker should own name");
        vm.stopPrank();

        // Legitimate user tries to register
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        vm.expectRevert("Name taken");
        ens.register{value: registrationFee}(name);
        vm.stopPrank();
    }

    function test_AttackENSSquatting() public {
        // Attacker tries to register many names
        vm.startPrank(attacker);
        vm.deal(attacker, 10 ether);
        
        string[5] memory names = ["aaa.d4l", "bbb.d4l", "ccc.d4l", "ddd.d4l", "eee.d4l"];
        bytes32[] memory nameHashes = new bytes32[](5);
        
        for(uint i = 0; i < names.length; i++) {
            nameHashes[i] = ens.register{value: 0.1 ether}(names[i]);
            assertEq(ens.getOwner(nameHashes[i]), attacker, "Attacker should own name");
        }

        // Try to sell/transfer names
        vm.deal(user1, 1 ether);
        vm.stopPrank();

        vm.prank(attacker);
        ens.transfer(nameHashes[0], user1);
        assertEq(ens.getOwner(nameHashes[0]), user1, "Transfer should succeed");
    }
} 