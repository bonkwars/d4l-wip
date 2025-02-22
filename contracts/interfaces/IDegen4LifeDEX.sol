// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDegen4LifeDEX {
    // Events
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

    event RouterUpdated(address indexed router);
    event PriceOracleUpdated(address indexed oracle);
    event FeeCollectorUpdated(address indexed collector);

    // External functions
    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function swapExactETHForTokens(
        address tokenOut,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function swapExactTokensForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address payable to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    // View functions
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function getPriceImpact(
        address token,
        uint256 amount,
        bool isBuy
    ) external view returns (uint256);

    // Admin functions
    function setFees(
        uint256 _swapFee,
        uint256 _protocolFee,
        uint256 _lpFee
    ) external;

    function setRouter(address _router) external;
    function setPriceOracle(address _oracle) external;
    function setFeeCollector(address _collector) external;
    function pause() external;
    function unpause() external;
} 