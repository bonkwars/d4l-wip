// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/modules/OrderBookModule.sol";
import "../contracts/interfaces/IContractRegistry.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OrderBookModuleTest is Test {
    OrderBookModule public implementation;
    OrderBookModule public orderBook;
    address public owner;
    address public user1;
    address public user2;
    address public registry;
    address public mockToken1;
    address public mockToken2;

    event OrderCreated(bytes32 indexed orderId, address indexed maker, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderFilled(bytes32 indexed orderId, address indexed taker, uint256 fillAmount);
    event OrderCancelled(bytes32 indexed orderId);
    event TradeExecuted(bytes32 indexed orderId, address indexed maker, address indexed taker, uint256 amount, uint256 price);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        registry = makeAddr("registry");
        mockToken1 = makeAddr("token1");
        mockToken2 = makeAddr("token2");

        // Deploy implementation
        implementation = new OrderBookModule();
        
        // Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            OrderBookModule.initialize.selector,
            registry
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        // Get orderBook instance
        orderBook = OrderBookModule(address(proxy));

        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // Mock token approvals
        vm.mockCall(
            mockToken1,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        vm.mockCall(
            mockToken2,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        // Mock token transfers
        vm.mockCall(
            mockToken1,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );

        vm.mockCall(
            mockToken2,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
    }

    function test_InitialSetup() public {
        assertEq(address(orderBook.registry()), registry);
        assertEq(orderBook.owner(), owner);
    }

    function test_CreateLimitOrder() public {
        uint256 amountIn = 1000e18;
        uint256 amountOut = 900e18;
        bool isBuyOrder = true;

        vm.startPrank(user1);
        
        bytes32 orderId = orderBook.createLimitOrder(
            mockToken1,
            mockToken2,
            amountIn,
            amountOut,
            isBuyOrder
        );

        // Get order details
        (
            address maker,
            address tokenIn,
            address tokenOut,
            uint256 orderAmountIn,
            uint256 orderAmountOut,
            uint256 timestamp,
            bool orderIsBuy,
            OrderBookModule.OrderStatus status
        ) = _unpackOrder(orderBook.getOrder(orderId));

        assertEq(maker, user1);
        assertEq(tokenIn, mockToken1);
        assertEq(tokenOut, mockToken2);
        assertEq(orderAmountIn, amountIn);
        assertEq(orderAmountOut, amountOut);
        assertEq(orderIsBuy, isBuyOrder);
        assertEq(uint8(status), uint8(OrderBookModule.OrderStatus.OPEN));

        vm.stopPrank();
    }

    function test_CancelOrder() public {
        // Create order first
        vm.startPrank(user1);
        bytes32 orderId = orderBook.createLimitOrder(
            mockToken1,
            mockToken2,
            1000e18,
            900e18,
            true
        );

        // Cancel order
        orderBook.cancelOrder(orderId);

        // Verify status
        (, , , , , , , OrderBookModule.OrderStatus status) = _unpackOrder(orderBook.getOrder(orderId));
        assertEq(uint8(status), uint8(OrderBookModule.OrderStatus.CANCELLED));

        vm.stopPrank();
    }

    function test_GetOrderBook() public {
        // Create multiple orders
        vm.startPrank(user1);
        orderBook.createLimitOrder(mockToken1, mockToken2, 1000e18, 900e18, true);
        orderBook.createLimitOrder(mockToken1, mockToken2, 2000e18, 1800e18, true);
        vm.stopPrank();

        vm.startPrank(user2);
        orderBook.createLimitOrder(mockToken1, mockToken2, 1500e18, 1350e18, false);
        vm.stopPrank();

        // Get order book
        (OrderBookModule.Order[] memory buyOrders, OrderBookModule.Order[] memory sellOrders) = 
            orderBook.getOrderBook(mockToken1, mockToken2);

        assertEq(buyOrders.length, 2);
        assertEq(sellOrders.length, 1);
    }

    function test_GetUserOrders() public {
        vm.startPrank(user1);
        orderBook.createLimitOrder(mockToken1, mockToken2, 1000e18, 900e18, true);
        orderBook.createLimitOrder(mockToken1, mockToken2, 2000e18, 1800e18, false);
        vm.stopPrank();

        bytes32[] memory userOrders = orderBook.getUserOrders(user1);
        assertEq(userOrders.length, 2);
    }

    function test_RevertWhenInvalidPair() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid pair");
        orderBook.createLimitOrder(
            mockToken1,
            mockToken1,
            1000e18,
            900e18,
            true
        );
        vm.stopPrank();
    }

    function test_RevertWhenInvalidAmounts() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid amounts");
        orderBook.createLimitOrder(
            mockToken1,
            mockToken2,
            0,
            900e18,
            true
        );
        vm.stopPrank();
    }

    function test_RevertWhenUnauthorizedCancellation() public {
        vm.startPrank(user1);
        bytes32 orderId = orderBook.createLimitOrder(
            mockToken1,
            mockToken2,
            1000e18,
            900e18,
            true
        );
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Not order maker");
        orderBook.cancelOrder(orderId);
        vm.stopPrank();
    }

    function test_OrderMatching() public {
        // Create buy order
        vm.startPrank(user1);
        bytes32 buyOrderId = orderBook.createLimitOrder(
            mockToken1,
            mockToken2,
            1000e18,  // Willing to pay 1000 tokens
            800e18,   // For at least 800 tokens (price = 1.25)
            true
        );
        vm.stopPrank();

        // Create matching sell order
        vm.startPrank(user2);
        bytes32 sellOrderId = orderBook.createLimitOrder(
            mockToken2,   // Selling token2
            mockToken1,   // For token1
            800e18,    // Selling 800 token2
            900e18,    // For at least 900 token1 (price ≈ 1.125)
            false
        );
        vm.stopPrank();

        // Verify orders are matched
        (, , , , , , , OrderBookModule.OrderStatus buyStatus) = _unpackOrder(orderBook.getOrder(buyOrderId));
        (, , , , , , , OrderBookModule.OrderStatus sellStatus) = _unpackOrder(orderBook.getOrder(sellOrderId));

        assertEq(uint8(buyStatus), uint8(OrderBookModule.OrderStatus.FILLED));
        assertEq(uint8(sellStatus), uint8(OrderBookModule.OrderStatus.FILLED));
    }

    // Helper function to unpack Order struct
    function _unpackOrder(OrderBookModule.Order memory order) internal pure returns (
        address maker,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp,
        bool isBuyOrder,
        OrderBookModule.OrderStatus status
    ) {
        return (
            order.maker,
            order.tokenIn,
            order.tokenOut,
            order.amountIn,
            order.amountOut,
            order.timestamp,
            order.isBuyOrder,
            order.status
        );
    }
} 