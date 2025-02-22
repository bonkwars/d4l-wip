// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/dex/core/D4LDex.sol";
import "../contracts/interfaces/IContractRegistry.sol";
import "../contracts/interfaces/dex/IDexRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

error OwnableUnauthorizedAccount(address account);
error EnforcedPause();

contract D4LDexTest is Test {
    D4LDex public implementation;
    D4LDex public dex;
    address public owner;
    address public user1;
    address public user2;
    address public registry;
    address public weth;
    address public feeCollector;
    address public mockRouter;
    address public mockToken;

    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    event FeeUpdated(
        uint256 swapFee,
        uint256 protocolFee,
        uint256 lpFee
    );

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        registry = makeAddr("registry");
        weth = makeAddr("weth");
        feeCollector = makeAddr("feeCollector");
        mockRouter = makeAddr("router");
        mockToken = makeAddr("token");

        // Deploy implementation
        implementation = new D4LDex();
        
        // Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            D4LDex.initialize.selector,
            registry,
            weth,
            feeCollector
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        // Get dex instance
        dex = D4LDex(payable(address(proxy)));

        // Setup mock registry responses
        vm.mockCall(
            registry,
            abi.encodeWithSelector(IContractRegistry.getContractAddressByName.selector, "DEX_ROUTER"),
            abi.encode(mockRouter)
        );

        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(address(dex), 100 ether);
    }

    function test_InitialSetup() public view {
        assertEq(address(dex.registry()), registry);
        assertEq(dex.WETH(), weth);
        assertEq(dex.feeCollector(), feeCollector);
        assertEq(dex.owner(), owner);
        
        // Check default fees
        assertEq(dex.swapFee(), 30);      // 0.3%
        assertEq(dex.protocolFee(), 10);  // 0.1%
        assertEq(dex.lpFee(), 20);        // 0.2%
    }

    function test_SetFees() public {
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit FeeUpdated(30, 10, 20);
        dex.setFees(30, 10, 20);
        
        assertEq(dex.swapFee(), 30);
        assertEq(dex.protocolFee(), 10);
        assertEq(dex.lpFee(), 20);
        
        vm.stopPrank();
    }

    function test_SwapExactTokensForTokens() public {
        uint256 amountIn = 1000e18;
        uint256 amountOut = 900e18;
        uint256 minAmountOut = 800e18;
        uint256 fee = (amountIn * dex.swapFee()) / 10000;
        
        // Setup mock router response
        vm.mockCall(
            mockRouter,
            abi.encodeWithSelector(IDexRouter.executeSwap.selector),
            abi.encode(amountOut)
        );

        // Setup mock token approvals
        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );

        vm.startPrank(user1);
        
        vm.expectEmit(true, true, true, true);
        emit Swap(user1, mockToken, weth, amountIn, amountOut, fee);

        uint256 result = dex.swapExactTokensForTokens(
            mockToken,
            weth,
            amountIn,
            minAmountOut,
            user1,
            block.timestamp + 1 hours
        );

        assertEq(result, amountOut);
        vm.stopPrank();
    }

    function test_SwapExactETHForTokens() public {
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 1000e18;
        uint256 minAmountOut = 900e18;
        uint256 fee = (ethAmount * dex.swapFee()) / 10000;

        // Setup mock router response
        vm.mockCall(
            mockRouter,
            abi.encodeWithSelector(IDexRouter.executeETHSwap.selector),
            abi.encode(tokenAmount)
        );

        vm.startPrank(user1);
        
        vm.expectEmit(true, true, true, true);
        emit Swap(user1, weth, mockToken, ethAmount, tokenAmount, fee);

        uint256 result = dex.swapExactETHForTokens{value: ethAmount}(
            mockToken,
            minAmountOut,
            user1,
            block.timestamp + 1 hours
        );

        assertEq(result, tokenAmount);
        vm.stopPrank();
    }

    function test_RevertWhenSwappingSameToken() public {
        vm.startPrank(user1);
        vm.expectRevert("Same token");
        dex.swapExactTokensForTokens(
            mockToken,
            mockToken,
            1000e18,
            900e18,
            user1,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_RevertWhenSwapExpired() public {
        vm.startPrank(user1);
        vm.expectRevert("Expired");
        dex.swapExactTokensForTokens(
            mockToken,
            weth,
            1000e18,
            900e18,
            user1,
            block.timestamp - 1
        );
        vm.stopPrank();
    }

    function test_RevertWhenZeroAmount() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        dex.swapExactTokensForTokens(
            address(mockToken),
            weth,
            0,
            0,
            address(this),
            block.timestamp
        );
        
        vm.stopPrank();
    }

    function test_PauseAndUnpause() public {
        vm.startPrank(owner);
        
        dex.pause();
        assertTrue(dex.paused());
        
        vm.expectRevert(
            abi.encodeWithSelector(
                EnforcedPause.selector
            )
        );
        dex.swapExactTokensForTokens(
            address(mockToken),
            weth,
            1000,
            0,
            address(this),
            block.timestamp
        );
        
        dex.unpause();
        assertFalse(dex.paused());
        
        vm.stopPrank();
    }

    function test_OnlyOwnerFunctions() public {
        vm.startPrank(user1);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        dex.setFeeCollector(address(0x123));
        
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        dex.setFees(30, 10, 20);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        dex.pause();
        
        vm.stopPrank();
    }
} 