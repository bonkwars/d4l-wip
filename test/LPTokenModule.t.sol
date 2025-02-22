// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/modules/LPTokenModule.sol";
import "../contracts/interfaces/IContractRegistry.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LPTokenModuleTest is Test {
    LPTokenModule public implementation;
    LPTokenModule public lpToken;
    address public owner;
    address public user1;
    address public user2;
    address public registry;
    address public mockTokenA;
    address public mockTokenB;

    event PositionCreated(uint256 indexed tokenId, address indexed owner, address tokenA, address tokenB, uint256 amountA, uint256 amountB);
    event PositionModified(uint256 indexed tokenId, uint256 newAmountA, uint256 newAmountB);
    event PositionClosed(uint256 indexed tokenId);
    event FeesHarvested(uint256 indexed tokenId, uint256 amount);
    event PositionStaked(uint256 indexed tokenId);
    event PositionUnstaked(uint256 indexed tokenId);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        registry = makeAddr("registry");
        mockTokenA = makeAddr("tokenA");
        mockTokenB = makeAddr("tokenB");

        // Deploy implementation
        implementation = new LPTokenModule();
        
        // Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            LPTokenModule.initialize.selector,
            registry
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        // Get lpToken instance
        lpToken = LPTokenModule(address(proxy));

        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // Mock token approvals
        vm.mockCall(
            mockTokenA,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        vm.mockCall(
            mockTokenB,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );
    }

    function test_InitialSetup() public {
        assertEq(address(lpToken.registry()), registry);
        assertEq(lpToken.owner(), owner);
        assertEq(lpToken.name(), "D4L Liquidity Position");
        assertEq(lpToken.symbol(), "D4L-LP");
    }

    function test_CreatePosition() public {
        uint256 amountA = 1000e18;
        uint256 amountB = 900e18;

        vm.startPrank(user1);
        
        uint256 tokenId = lpToken.createPosition(
            mockTokenA,
            mockTokenB,
            amountA,
            amountB
        );

        // Get position details
        (
            address posTokenA,
            address posTokenB,
            uint256 posAmountA,
            uint256 posAmountB,
            uint256 posLiquidity,
            uint256 posStartTime,
            uint256 posLastHarvestTime,
            uint256 posAccumulatedFees,
            bool posIsStaked
        ) = lpToken.positions(tokenId);

        assertEq(posTokenA, mockTokenA);
        assertEq(posTokenB, mockTokenB);
        assertEq(posAmountA, amountA);
        assertEq(posAmountB, amountB);
        assertEq(posIsStaked, false);
        assertEq(lpToken.ownerOf(tokenId), user1);

        vm.stopPrank();
    }

    function test_ModifyPosition() public {
        // Create position first
        vm.startPrank(user1);
        uint256 tokenId = lpToken.createPosition(
            mockTokenA,
            mockTokenB,
            1000e18,
            900e18
        );

        // Modify position
        uint256 newAmountA = 1500e18;
        uint256 newAmountB = 1350e18;
        lpToken.modifyPosition(tokenId, newAmountA, newAmountB);

        // Get updated position
        (
            address posTokenA,
            address posTokenB,
            uint256 posAmountA,
            uint256 posAmountB,
            uint256 posLiquidity,
            uint256 posStartTime,
            uint256 posLastHarvestTime,
            uint256 posAccumulatedFees,
            bool posIsStaked
        ) = lpToken.positions(tokenId);

        assertEq(posAmountA, newAmountA);
        assertEq(posAmountB, newAmountB);

        vm.stopPrank();
    }

    function test_StakePosition() public {
        vm.startPrank(user1);
        uint256 tokenId = lpToken.createPosition(
            mockTokenA,
            mockTokenB,
            1000e18,
            900e18
        );

        // Stake position
        lpToken.stakePosition(tokenId);

        // Verify staking
        (
            address posTokenA,
            address posTokenB,
            uint256 posAmountA,
            uint256 posAmountB,
            uint256 posLiquidity,
            uint256 posStartTime,
            uint256 posLastHarvestTime,
            uint256 posAccumulatedFees,
            bool posIsStaked
        ) = lpToken.positions(tokenId);

        assertTrue(posIsStaked);

        vm.stopPrank();
    }

    function test_UnstakePosition() public {
        vm.startPrank(user1);
        uint256 tokenId = lpToken.createPosition(
            mockTokenA,
            mockTokenB,
            1000e18,
            900e18
        );

        // Stake and then unstake
        lpToken.stakePosition(tokenId);
        lpToken.unstakePosition(tokenId);

        // Verify unstaking
        (
            address posTokenA,
            address posTokenB,
            uint256 posAmountA,
            uint256 posAmountB,
            uint256 posLiquidity,
            uint256 posStartTime,
            uint256 posLastHarvestTime,
            uint256 posAccumulatedFees,
            bool posIsStaked
        ) = lpToken.positions(tokenId);

        assertFalse(posIsStaked);

        vm.stopPrank();
    }

    function test_HarvestFees() public {
        vm.startPrank(user1);
        uint256 tokenId = lpToken.createPosition(
            mockTokenA,
            mockTokenB,
            1000e18,
            900e18
        );

        // Move forward in time
        vm.warp(block.timestamp + 30 days);

        // Harvest fees
        uint256 fees = lpToken.harvestFees(tokenId);
        assertTrue(fees > 0);

        // Get updated position
        (
            address posTokenA,
            address posTokenB,
            uint256 posAmountA,
            uint256 posAmountB,
            uint256 posLiquidity,
            uint256 posStartTime,
            uint256 posLastHarvestTime,
            uint256 posAccumulatedFees,
            bool posIsStaked
        ) = lpToken.positions(tokenId);

        assertEq(posAccumulatedFees, fees);
        assertEq(posLastHarvestTime, block.timestamp);

        vm.stopPrank();
    }

    function test_GetUserPositions() public {
        vm.startPrank(user1);
        lpToken.createPosition(mockTokenA, mockTokenB, 1000e18, 900e18);
        lpToken.createPosition(mockTokenA, mockTokenB, 2000e18, 1800e18);
        vm.stopPrank();

        uint256[] memory positions = lpToken.getUserPositions(user1, mockTokenA);
        assertEq(positions.length, 2);
    }

    function test_RevertWhenInvalidTokens() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid tokens");
        lpToken.createPosition(
            address(0),
            mockTokenB,
            1000e18,
            900e18
        );
        vm.stopPrank();
    }

    function test_RevertWhenInvalidAmounts() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid amounts");
        lpToken.createPosition(
            mockTokenA,
            mockTokenB,
            0,
            900e18
        );
        vm.stopPrank();
    }

    function test_RevertWhenUnauthorizedModification() public {
        vm.startPrank(user1);
        uint256 tokenId = lpToken.createPosition(
            mockTokenA,
            mockTokenB,
            1000e18,
            900e18
        );
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Not authorized");
        lpToken.modifyPosition(tokenId, 2000e18, 1800e18);
        vm.stopPrank();
    }

    function test_RevertWhenModifyingStakedPosition() public {
        vm.startPrank(user1);
        uint256 tokenId = lpToken.createPosition(
            mockTokenA,
            mockTokenB,
            1000e18,
            900e18
        );

        lpToken.stakePosition(tokenId);

        vm.expectRevert("Position is staked");
        lpToken.modifyPosition(tokenId, 2000e18, 1800e18);
        vm.stopPrank();
    }

    function test_RevertWhenUnstakingUnstakedPosition() public {
        vm.startPrank(user1);
        uint256 tokenId = lpToken.createPosition(
            mockTokenA,
            mockTokenB,
            1000e18,
            900e18
        );

        vm.expectRevert("Not staked");
        lpToken.unstakePosition(tokenId);
        vm.stopPrank();
    }

    function test_ClosePosition() public {
        // Setup initial position
        uint256 amountA = 1000e18;
        uint256 amountB = 900e18;

        vm.startPrank(user1);
        uint256 tokenId = lpToken.createPosition(
            mockTokenA,
            mockTokenB,
            amountA,
            amountB
        );

        // Close position
        lpToken.closePosition(tokenId);

        // Verify position closure
        (
            address posTokenA,
            address posTokenB,
            uint256 posAmountA,
            uint256 posAmountB,
            uint256 posLiquidity,
            uint256 posStartTime,
            uint256 posLastHarvestTime,
            uint256 posAccumulatedFees,
            bool posIsStaked
        ) = lpToken.positions(tokenId);

        assertEq(posAmountA, 0);
        assertEq(posAmountB, 0);
        assertFalse(posIsStaked);
        vm.stopPrank();
    }
} 