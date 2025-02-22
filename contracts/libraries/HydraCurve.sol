// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UD60x18} from "@prb/math/src/UD60x18.sol";


library HydraCurve {
    
    uint256 private constant ALPHA = 105e16; // 1.05 in 18 decimals
    uint256 private constant BETA = 25e16;  // 0.25 in 18 decimals
    uint256 private constant GAMMA = 1e18;    // 1.0 in 18 decimals
    uint256 private constant BASE = 1e18;
    uint256 private constant PRECISION_SQRT = 1e9; // sqrt(1e18)

    /**
     * @dev Calculates price using HydraCurve formula:
     * P(S) = α * (1 - e^(-S/γ)) + β * S
     * Where:
     * - α controls the asymptotic price
     * - β controls the linear growth component
     * - γ controls the exponential decay rate
     */
    function calculatePrice(uint256 supply) internal pure returns (uint256) {
        UD60x18 S = UD60x18.wrap(supply).div(UD60x18.wrap(BASE));
        UD60x18 expTerm = UD60x18.wrap(ALPHA).mul(
            UD60x18.wrap(BASE).sub(UD60x18.wrap(GAMMA).sub(S.div(UD60x18.wrap(GAMMA)).exp()))
        );
        UD60x18 linearTerm = UD60x18.wrap(BETA).mul(S);
        return expTerm.add(linearTerm).unwrap();
    }

    /**
     * @dev Calculates required deposit by integrating P(S) from 0 to S:
     * ∫P(S)dS = αγ(1 - e^(-S/γ)) + (β/2)S²
     */
    function calculateDeposit(uint256 supply) internal pure returns (uint256) {
        UD60x18 S = UD60x18.wrap(supply).div(UD60x18.wrap(BASE));
        UD60x18 integralExp = UD60x18.wrap(ALPHA).mul(UD60x18.wrap(GAMMA)).mul(
            UD60x18.wrap(BASE).sub(S.div(UD60x18.wrap(GAMMA)).exp())
        );
        UD60x18 integralLinear = UD60x18.wrap(BETA).mul(S.pow(UD60x18.wrap(2e18))).div(UD60x18.wrap(2e18));
        return integralExp.add(integralLinear).unwrap();
    }

    /**
     * @dev Calculates price impact/slippage for a given trade size
     * @param supply Current token supply
     * @param deltaS Trade size in tokens
     * @return slippage Slippage percentage in 18 decimals (1e18 = 100%)
     */
    function calculateSlippage(
        uint256 supply,
        uint256 deltaS
    ) internal pure returns (uint256) {
        if (deltaS == 0) return 0;
        
        uint256 S = supply / BASE;
        uint256 P_initial = calculatePrice(supply);
        uint256 P_final = calculatePrice(supply + deltaS);
        
        // Average price across the trade
        uint256 avgPrice = (P_initial + P_final) / 2e18;
        
        // Slippage = (AvgPrice - InitialPrice) / InitialPrice
        return (avgPrice - P_initial) / P_initial;
    }

    /**
     * @dev Calculates marginal slippage (price derivative)
     * dP/dS = (α/γ)e^(-S/γ) + β
     */
    function calculateMarginalSlippage(
        uint256 supply
    ) internal pure returns (uint256) {
        UD60x18 S = UD60x18.wrap(supply).div(UD60x18.wrap(BASE));
        UD60x18 expComponent = UD60x18.wrap(ALPHA).div(UD60x18.wrap(GAMMA)).mul(
            UD60x18.wrap(0).sub(S.div(UD60x18.wrap(GAMMA))).exp()
        );
        return expComponent.add(UD60x18.wrap(BETA)).unwrap();
    }

    /**
     * @dev Calculates price impact for a specific trade amount
     * Returns (expectedAmount, priceImpact)
     */
    function quoteTrade(
        uint256 supply,
        uint256 deltaS
    ) internal pure returns (uint256, uint256) {
        uint256 integralBefore = calculateDeposit(supply);
        uint256 integralAfter = calculateDeposit(supply + deltaS);
        uint256 expectedAmount = integralAfter - integralBefore;
        uint256 slippage = calculateSlippage(supply, deltaS);
        
        return (expectedAmount, slippage);
    }

    // Optimize power function
    function fastPow(uint256 x, uint256 n) internal pure returns (uint256) {
        if (n == 0) return PRECISION_SQRT;
        if (n == 1) return x;
        
        uint256 y = PRECISION_SQRT;
        while (n > 1) {
            if (n % 2 == 0) {
                x = (x * x) / PRECISION_SQRT;
                n = n / 2;
            } else {
                y = (x * y) / PRECISION_SQRT;
                x = (x * x) / PRECISION_SQRT;
                n = (n - 1) / 2;
            }
        }
        return (x * y) / PRECISION_SQRT;
    }
} 