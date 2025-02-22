// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/IHydraCurve.sol";

contract MockHydraCurve is IHydraCurve {
    mapping(address => CurveParams) public curves;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function initialize(address initialOwner) external {
        owner = initialOwner;
    }

    function initializeCurve(
        address token,
        CurveParams calldata params
    ) external {
        curves[token] = params;
        emit CurveInitialized(
            token,
            params.initialPrice,
            params.initialSupply,
            params.maxSupply,
            params.baseWeight,
            params.priceMultiplier
        );
    }

    function calculatePrice(
        address token,
        uint256 supply
    ) external view returns (uint256) {
        CurveParams memory params = curves[token];
        return params.initialPrice;
    }

    function calculatePriceImpact(
        address token,
        uint256 amount,
        bool isBuy
    ) external view returns (uint256) {
        return 100; // 1% impact
    }

    function getCurveParams(
        address token
    ) external view returns (
        uint256 initialPrice,
        uint256 initialSupply,
        uint256 maxSupply,
        uint256 baseWeight,
        uint256 priceMultiplier
    ) {
        CurveParams memory params = curves[token];
        return (
            params.initialPrice,
            params.initialSupply,
            params.maxSupply,
            params.baseWeight,
            params.priceMultiplier
        );
    }

    function calculateBuyAmount(
        address token,
        uint256 ethAmount
    ) external view returns (uint256) {
        return ethAmount * 100; // Mock conversion
    }

    function calculateSellAmount(
        address token,
        uint256 tokenAmount
    ) external view returns (uint256) {
        return tokenAmount / 100; // Mock conversion
    }

    function updateCurveParams(
        address token,
        CurveParams memory params
    ) external {
        curves[token] = params;
        emit PriceMultiplierUpdated(token, params.priceMultiplier);
    }
} 