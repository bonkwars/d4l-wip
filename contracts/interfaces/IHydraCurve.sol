// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface IHydraCurve {
    function initialize(address initialOwner) external;

    function initializeCurve(
        address token,
        CurveParams calldata params
    ) external;

    function calculatePrice(
        address token,
        uint256 supply
    ) external view returns (uint256);

    function calculatePriceImpact(
        address token,
        uint256 amount,
        bool isBuy
    ) external view returns (uint256);

    function getCurveParams(
        address token
    ) external view returns (
        uint256 initialPrice,
        uint256 initialSupply,
        uint256 maxSupply,
        uint256 baseWeight,
        uint256 priceMultiplier
    );

    struct CurveParams {
        uint256 initialPrice;
        uint256 initialSupply;
        uint256 maxSupply;
        uint256 baseWeight;
        uint256 priceMultiplier;
    }

    event CurveInitialized(
        address indexed token,
        uint256 initialPrice,
        uint256 initialSupply,
        uint256 maxSupply,
        uint256 baseWeight,
        uint256 priceMultiplier
    );

    event PriceUpdated(address indexed token, uint256 price, uint256 supply);
    
    event PriceMultiplierUpdated(address indexed token, uint256 multiplier);

    function calculateBuyAmount(address token, uint256 ethAmount) external view returns (uint256);
    function calculateSellAmount(address token, uint256 tokenAmount) external view returns (uint256);
    function updateCurveParams(address token, CurveParams memory params) external;
} 