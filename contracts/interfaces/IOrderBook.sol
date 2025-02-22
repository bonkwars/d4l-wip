// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOrderBook {
    enum OrderStatus {
        OPEN,
        FILLED,
        CANCELLED
    }

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

    event OrderCreated(bytes32 indexed orderId, address indexed maker, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderFilled(bytes32 indexed orderId, address indexed taker, uint256 fillAmount);
    event OrderCancelled(bytes32 indexed orderId);
    event TradeExecuted(bytes32 indexed orderId, address indexed maker, address indexed taker, uint256 amount, uint256 price);

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
    ) external returns (bytes32);

    /**
     * @notice Cancels an open limit order
     * @param orderId The ID of the order to cancel
     */
    function cancelOrder(bytes32 orderId) external;

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
        );

    /**
     * @notice Gets all orders for a user
     * @param user Address of the user
     * @return orders Array of order IDs
     */
    function getUserOrders(address user) external view returns (bytes32[] memory);

    /**
     * @notice Gets details of a specific order
     * @param orderId The ID of the order
     * @return order The order details
     */
    function getOrder(bytes32 orderId) external view returns (Order memory);
} 