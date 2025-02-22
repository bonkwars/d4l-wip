// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IHydraCurve.sol";

contract HydraCurve is Initializable, OwnableUpgradeable, IHydraCurve {
    mapping(address => CurveParams) public curves;
    mapping(address => bool) public isCurveInitialized;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        __Context_init();
        __Ownable_init(initialOwner);
       
    }

  

    function initializeCurve(
        address token,
        CurveParams calldata params
    ) external onlyOwner {
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
    ) external view returns (uint256) {
        require(isCurveInitialized[token], "Curve not initialized");
        CurveParams memory params = curves[token];
        
        if (supply == 0) return params.initialPrice;
        if (supply >= params.maxSupply) revert("Supply exceeds max");

        uint256 price = params.initialPrice;
        
        // Base curve component
        price = price * (supply + params.baseWeight) / params.baseWeight;
        
        // Exponential component
        uint256 supplyRatio = (supply * 1e18) / params.maxSupply;
        price = price * (1e18 + supplyRatio) / 1e18;
        
        // Apply multiplier
        price = price * params.priceMultiplier / 1e18;
        
        return price;
    }

    function calculatePriceImpact(
        address token,
        uint256 amount,
        bool isBuy
    ) external view returns (uint256) {
        require(isCurveInitialized[token], "Curve not initialized");
        CurveParams memory params = curves[token];
        
        uint256 currentSupply = params.initialSupply;
        uint256 currentPrice = this.calculatePrice(token, currentSupply);
        
        uint256 newSupply;
        if (isBuy) {
            newSupply = currentSupply + amount;
        } else {
            newSupply = currentSupply > amount ? currentSupply - amount : 0;
        }
        
        uint256 newPrice = this.calculatePrice(token, newSupply);
        
        if (isBuy) {
            return ((newPrice - currentPrice) * 10000) / currentPrice;
        } else {
            return ((currentPrice - newPrice) * 10000) / currentPrice;
        }
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
    ) external view returns (uint256) {
        require(isCurveInitialized[token], "Curve not initialized");
        CurveParams memory params = curves[token];
        
        uint256 currentPrice = this.calculatePrice(token, params.initialSupply);
        return (ethAmount * 1e18) / currentPrice;
    }

    function calculateSellAmount(
        address token,
        uint256 tokenAmount
    ) external view returns (uint256) {
        require(isCurveInitialized[token], "Curve not initialized");
        CurveParams memory params = curves[token];
        
        uint256 currentPrice = this.calculatePrice(token, params.initialSupply);
        return (tokenAmount * currentPrice) / 1e18;
    }

    function updateCurveParams(
        address token,
        CurveParams memory params
    ) external onlyOwner {
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