// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPrivacy {
    struct PrivateOrder {
        bytes32 commitment;
        uint256 timestamp;
        uint256 expiryTime;
        bool executed;
        bool cancelled;
    }

    struct OrderReveal {
        address maker;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        bytes signature;
    }

    event OrderCommitted(bytes32 indexed commitment, uint256 timestamp);
    event OrderRevealed(bytes32 indexed commitment, address indexed maker, address tokenIn, address tokenOut);
    event OrderExecuted(bytes32 indexed commitment, uint256 amountIn, uint256 amountOut);
    event OrderCancelled(bytes32 indexed commitment);

    /**
     * @notice Commits to a private order without revealing details
     * @param commitment Hash of order details
     * @param delay Time before order can be revealed
     */
    function commitOrder(
        bytes32 commitment,
        uint256 delay
    ) external;

    /**
     * @notice Reveals and executes a private order
     * @param orderData Order details for reveal
     */
    function revealAndExecute(
        OrderReveal calldata orderData
    ) external;

    /**
     * @notice Cancels a committed order
     * @param commitment Order commitment hash
     */
    function cancelOrder(bytes32 commitment) external;

    /**
     * @notice Gets all orders for a user
     * @param user User address
     * @return commitments Array of order commitments
     */
    function getUserOrders(address user) external view returns (bytes32[] memory);

    /**
     * @notice Gets details of an order
     * @param commitment Order commitment hash
     * @return order The order details
     */
    function getOrder(bytes32 commitment) external view returns (PrivateOrder memory);

    /**
     * @notice Checks if a commitment has been used
     * @param commitment Order commitment hash
     * @return used Whether the commitment has been used
     */
    function usedCommitments(bytes32 commitment) external view returns (bool);
} 