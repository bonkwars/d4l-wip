// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "../interfaces/IContractRegistry.sol";
import "../interfaces/IOrderBook.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title OrderBookModule
 * @notice Implements a hybrid AMM-Order Book model for limit orders and advanced trading
 */
contract OrderBookModule is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    // State variables
    IContractRegistry public registry;
    
    struct Order {
        address maker;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 timestamp;
        bool isBuyOrder;
        OrderStatus status;
    }

    enum OrderStatus {
        OPEN,
        FILLED,
        CANCELLED
    }

    struct OrderBook {
        Order[] buyOrders;
        Order[] sellOrders;
        uint256 lastPrice;
        uint256 volume24h;
    }

    // Mappings
    mapping(bytes32 => OrderBook) private orderBooks;    // tokenIn+tokenOut => OrderBook
    mapping(bytes32 => Order) private orders;           // orderId => Order
    mapping(address => bytes32[]) private userOrders;   // user => orderIds

    // Events
    event OrderCreated(bytes32 indexed orderId, address indexed maker, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderFilled(bytes32 indexed orderId, address indexed taker, uint256 fillAmount);
    event OrderCancelled(bytes32 indexed orderId);
    event TradeExecuted(bytes32 indexed orderId, address indexed maker, address indexed taker, uint256 amount, uint256 price);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _registry) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_registry != address(0), "Invalid registry");
        registry = IContractRegistry(_registry);
    }

    /**
     * @notice Creates a limit order
     * @param tokenIn Address of input token
     * @param tokenOut Address of output token
     * @param amountIn Amount of input tokens
     * @param amountOut Minimum amount of output tokens
     * @param isBuyOrder Whether this is a buy order
     * @return orderId The ID of the created order
     */
    function createLimitOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool isBuyOrder
    ) external nonReentrant whenNotPaused returns (bytes32) {
        require(tokenIn != tokenOut, "Invalid pair");
        require(amountIn > 0 && amountOut > 0, "Invalid amounts");

        bytes32 orderId = keccak256(
            abi.encodePacked(
                msg.sender,
                tokenIn,
                tokenOut,
                amountIn,
                amountOut,
                block.timestamp
            )
        );

        Order memory order = Order({
            maker: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            timestamp: block.timestamp,
            isBuyOrder: isBuyOrder,
            status: OrderStatus.OPEN
        });

        // Get normalized order book ID
        bytes32 bookId = _getOrderBookId(tokenIn, tokenOut);
        OrderBook storage book = orderBooks[bookId];

        // Add order to the correct side of the book
        if (isBuyOrder) {
            book.buyOrders.push(order);
        } else {
            book.sellOrders.push(order);
        }

        orders[orderId] = order;
        userOrders[msg.sender].push(orderId);

        emit OrderCreated(orderId, msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        
        // Try to match order immediately
        _matchOrder(orderId);

        return orderId;
    }

    /**
     * @notice Cancels an open limit order
     * @param orderId The ID of the order to cancel
     */
    function cancelOrder(bytes32 orderId) external nonReentrant {
        Order storage order = orders[orderId];
        require(order.maker == msg.sender, "Not order maker");
        require(order.status == OrderStatus.OPEN, "Invalid status");

        order.status = OrderStatus.CANCELLED;
        emit OrderCancelled(orderId);
    }

    /**
     * @notice Gets all open orders for a trading pair
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @return buyOrders Array of buy orders
     * @return sellOrders Array of sell orders
     */
    function getOrderBook(address tokenIn, address tokenOut) 
        external 
        view 
        returns (
            Order[] memory buyOrders,
            Order[] memory sellOrders
        ) 
    {
        bytes32 bookId = _getOrderBookId(tokenIn, tokenOut);
        OrderBook storage book = orderBooks[bookId];
        return (book.buyOrders, book.sellOrders);
    }

    /**
     * @notice Gets all orders for a user
     * @param user Address of the user
     * @return orders Array of order IDs
     */
    function getUserOrders(address user) external view returns (bytes32[] memory) {
        return userOrders[user];
    }

    /**
     * @notice Gets details of a specific order
     * @param orderId The ID of the order
     * @return order The order details
     */
    function getOrder(bytes32 orderId) external view returns (Order memory) {
        return orders[orderId];
    }

    // Internal functions

    function _matchOrder(bytes32 orderId) internal {
        Order storage order = orders[orderId];
        if (order.status != OrderStatus.OPEN) return;

        bytes32 bookId = _getOrderBookId(order.tokenIn, order.tokenOut);
        OrderBook storage book = orderBooks[bookId];

        // Get matching orders array
        Order[] storage matchingOrders = order.isBuyOrder ? book.sellOrders : book.buyOrders;

        // Try to match with each order
        for (uint i = 0; i < matchingOrders.length; i++) {
            Order storage matchingOrder = matchingOrders[i];
            if (matchingOrder.status != OrderStatus.OPEN) continue;

            // Skip if it's our own order
            if (matchingOrder.maker == order.maker) continue;

            // Check if tokens match (in either direction)
            if ((order.tokenIn == matchingOrder.tokenOut && order.tokenOut == matchingOrder.tokenIn) ||
                (order.tokenIn == matchingOrder.tokenIn && order.tokenOut == matchingOrder.tokenOut)) {
                if (_canMatch(order, matchingOrder)) {
                    _executeMatch(order, matchingOrder);
                    break;
                }
            }
        }
    }

    function _canMatch(Order memory order1, Order memory order2) internal pure returns (bool) {
        // Normalize orders so order1 is always the buy order
        if (!order1.isBuyOrder) {
            return _canMatch(order2, order1);
        }

        // At this point, order1 is buy and order2 is sell
        // Buy order: willing to pay more than seller's ask
        return order1.amountIn * order2.amountOut >= order1.amountOut * order2.amountIn;
    }

    function _executeMatch(Order storage order1, Order storage order2) internal {
        require(order1.status == OrderStatus.OPEN && order2.status == OrderStatus.OPEN, "Orders not open");
        
        // Transfer tokens
        if (order1.isBuyOrder) {
            // order1 is buy, order2 is sell
            IERC20(order1.tokenIn).transferFrom(order1.maker, order2.maker, order2.amountIn);
            IERC20(order2.tokenIn).transferFrom(order2.maker, order1.maker, order2.amountOut);
        } else {
            // order1 is sell, order2 is buy
            IERC20(order1.tokenIn).transferFrom(order1.maker, order2.maker, order1.amountIn);
            IERC20(order2.tokenIn).transferFrom(order2.maker, order1.maker, order1.amountOut);
        }
        
        // Calculate execution price
        uint256 executionPrice = order1.isBuyOrder ? 
            (order2.amountOut * 1e18) / order2.amountIn :
            (order1.amountOut * 1e18) / order1.amountIn;
        
        // Set both orders as filled in both the order book arrays and the orders mapping
        order1.status = OrderStatus.FILLED;
        order2.status = OrderStatus.FILLED;

        // Update orders in the orders mapping using the same ID calculation as createLimitOrder
        bytes32 order1Id = keccak256(
            abi.encodePacked(
                order1.maker,
                order1.tokenIn,
                order1.tokenOut,
                order1.amountIn,
                order1.amountOut,
                order1.timestamp
            )
        );
        bytes32 order2Id = keccak256(
            abi.encodePacked(
                order2.maker,
                order2.tokenIn,
                order2.tokenOut,
                order2.amountIn,
                order2.amountOut,
                order2.timestamp
            )
        );
        orders[order1Id] = order1;
        orders[order2Id] = order2;

        emit TradeExecuted(
            order1Id,
            order1.maker,
            order2.maker,
            order1.isBuyOrder ? order2.amountIn : order1.amountIn,
            executionPrice
        );
    }

    function _getOrderBookId(address tokenIn, address tokenOut) internal pure returns (bytes32) {
        // Always use the lower address as the first token to ensure consistent order book IDs
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        return keccak256(abi.encodePacked(token0, token1));
    }
} 