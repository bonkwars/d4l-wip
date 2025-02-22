// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library HydraMath {
    uint256 private constant PRECISION = 1e18;
    uint256 private constant Q128 = 2**128;
    
    // Add error messages
    error Overflow();
    error DivisionByZero();
    
    function calculateShares(
        uint256 x,
        uint256 y,
        uint256 totalShares,
        uint256 depositX,
        uint256 depositY
    ) internal pure returns (uint256 shares) {
        if (totalShares == 0) {
            return sqrt(depositX * depositY);
        }
        uint256 xRatio = (depositX * Q128) / x;
        uint256 yRatio = (depositY * Q128) / y;
        shares = (sqrt(xRatio * yRatio) * totalShares) / Q128;
    }
    
    // Complete the optimized sqrt function
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        
        uint256 xx = x;
        uint256 r = 1;
        
        // Optimized binary search
        if (xx >= 0x100000000000000000000000000000000) { xx >>= 128; r <<= 64; }
        if (xx >= 0x10000000000000000) { xx >>= 64; r <<= 32; }
        if (xx >= 0x100000000) { xx >>= 32; r <<= 16; }
        if (xx >= 0x10000) { xx >>= 16; r <<= 8; }
        if (xx >= 0x100) { xx >>= 8; r <<= 4; }
        if (xx >= 0x10) { xx >>= 4; r <<= 2; }
        if (xx >= 0x4) { r <<= 1; }
        
        r = (r + x/r) >> 1;
        r = (r + x/r) >> 1;
        r = (r + x/r) >> 1;
        
        return r;
    }

    function calculateLiquidity(
        uint256 z,
        uint256 steepness,
        uint256 width,
        uint256 power
    ) internal pure returns (uint256) {
        // Sigmoid component
        uint256 sigmoid = calculateSigmoid(z, steepness);
        
        // Gaussian component
        uint256 gaussian = calculateGaussian(z, width);
        
        // Rational component
        uint256 rational = calculateRational(z, power);
        
        // Combine components
        return (sigmoid + gaussian + rational) / 3;
    }

    function calculateZ(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        return (x * 1e18) / y;
    }

    function calculateSigmoid(
        uint256 x,
        uint256 steepness
    ) internal pure returns (uint256) {
        if (x == 0) return PRECISION;
        if (steepness == 0) return PRECISION / 2;

        // Calculate e^(-k*x) where k is steepness
        uint256 exp = _exp(-(int256(steepness * x) / int256(PRECISION)));
        
        // sigmoid(x) = 1 / (1 + e^(-k*x))
        return (PRECISION * PRECISION) / (PRECISION + exp);
    }

    function calculateGaussian(
        uint256 x,
        uint256 width
    ) internal pure returns (uint256) {
        if (x == 0) return PRECISION;
        if (width == 0) return 0;

        // Calculate (x/width)^2
        uint256 squared = (x * x) / (width * width);
        
        // gaussian(x) = e^(-(x/width)^2)
        return _exp(-(int256(squared)));
    }

    function calculateRational(
        uint256 x,
        uint256 power
    ) internal pure returns (uint256) {
        if (x == 0) return 0;
        if (power == 0) return PRECISION;

        // rational(x) = 1 / (1 + x^power)
        uint256 denominator = PRECISION + _pow(x, power);
        return (PRECISION * PRECISION) / denominator;
    }

    function _exp(int256 x) private pure returns (uint256) {
        // Implementation of e^x using Taylor series
        require(x <= 50 * int256(PRECISION), "Exp overflow");
        require(x >= -41 * int256(PRECISION), "Exp underflow");

        // If close to 0, return 1
        if (x == 0) return PRECISION;

        // Convert negative exponents
        bool isNegative = x < 0;
        if (isNegative) x = -x;

        // Calculate using first 4 terms of Taylor series
        uint256 result = PRECISION;  // 1
        uint256 term = uint256(x);   // x
        result += term;

        term = (term * uint256(x)) / (2 * PRECISION);
        result += term;

        term = (term * uint256(x)) / (3 * PRECISION);
        result += term;

        if (isNegative) {
            return (PRECISION * PRECISION) / result;
        }
        return result;
    }

    function _pow(uint256 x, uint256 n) private pure returns (uint256) {
        if (n == 0) return PRECISION;
        if (n == 1) return x;
        if (x == 0) return 0;

        uint256 result = PRECISION;
        uint256 base = x;
        
        while (n > 0) {
            if (n % 2 == 1) {
                result = (result * base) / PRECISION;
            }
            base = (base * base) / PRECISION;
            n /= 2;
        }
        
        return result;
    }

    // Add other required math functions...
} 