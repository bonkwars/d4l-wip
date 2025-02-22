// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IHydraCurve.sol";

abstract contract AbstractHydraCurve is Initializable, OwnableUpgradeable, IHydraCurve {
    mapping(address => CurveParams) public curves;
    mapping(address => bool) public isCurveInitialized;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external virtual initializer {
        __Ownable_init(initialOwner);
        __HydraCurve_init();
    }

    function __HydraCurve_init() internal virtual onlyInitializing {
        // Any additional initialization logic
    }

    function initializeCurve(
        address token,
        CurveParams calldata params
    ) external virtual onlyOwner {
        require(!isCurveInitialized[token], "Curve already initialized");
        require(params.initialPrice > 0, "Invalid initial price");
        require(params.initialSupply > 0, "Invalid initial supply");
        require(params.maxSupply >= params.initialSupply, "Invalid max supply");
        require(params.baseWeight > 0, "Invalid base weight");
        require(params.priceMultiplier > 0, "Invalid price multiplier");

        curves[token] = params;
        isCurveInitialized[token] = true;

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
    ) external virtual view returns (uint256);

    function calculatePriceImpact(
        address token,
        uint256 amount,
        bool isBuy
    ) external virtual view returns (uint256);

    function getCurveParams(
        address token
    ) external virtual view returns (
        uint256 initialPrice,
        uint256 initialSupply,
        uint256 maxSupply,
        uint256 baseWeight,
        uint256 priceMultiplier
    ) {
        require(isCurveInitialized[token], "Curve not initialized");
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
    ) external virtual view returns (uint256);

    function calculateSellAmount(
        address token,
        uint256 tokenAmount
    ) external virtual view returns (uint256);

    function updateCurveParams(
        address token,
        CurveParams memory params
    ) external virtual onlyOwner {
        require(isCurveInitialized[token], "Curve not initialized");
        require(params.initialPrice > 0, "Invalid initial price");
        require(params.initialSupply > 0, "Invalid initial supply");
        require(params.maxSupply >= params.initialSupply, "Invalid max supply");
        require(params.baseWeight > 0, "Invalid base weight");
        require(params.priceMultiplier > 0, "Invalid price multiplier");

        curves[token] = params;
        emit PriceMultiplierUpdated(token, params.priceMultiplier);
    }
} 