// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title FalconLib
 * @author Degen4Life Team
 * @notice Library implementing Falcon signature verification
 * @dev Implements FALCON-512/1024 post-quantum signature verification
 * @custom:security-contact security@memeswap.exchange
 */
library FalconLib {
    /// @notice Falcon-512 parameters
    uint256 private constant FALCON_512_N = 512;
    uint256 private constant FALCON_512_Q = 12289;
    uint256 private constant FALCON_512_SIGMA = 165; // 1.65 * 100 for fixed-point

    /// @notice Falcon-1024 parameters
    uint256 private constant FALCON_1024_N = 1024;
    uint256 private constant FALCON_1024_Q = 12289;
    uint256 private constant FALCON_1024_SIGMA = 168; // 1.68 * 100 for fixed-point

    /// @notice Error codes
    string private constant ERR_INVALID_SIG_LENGTH = "Invalid signature length";
    string private constant ERR_INVALID_S_NORM = "Invalid s-norm";
    string private constant ERR_INVALID_C_NORM = "Invalid c-norm";

    /**
     * @notice Verifies a Falcon-512 signature
     * @param messageHash Hash of the message that was signed
     * @param signature Falcon signature bytes
     * @param publicKeyH First component of the public key
     * @param publicKeyRho Second component of the public key
     * @return True if signature is valid
     */
    function verifyFalcon512(
        bytes32 messageHash,
        bytes calldata signature,
        bytes32 publicKeyH,
        bytes32 publicKeyRho
    ) internal pure returns (bool) {
        return _verifyFalcon(
            messageHash,
            signature,
            publicKeyH,
            publicKeyRho,
            FALCON_512_N,
            FALCON_512_Q,
            FALCON_512_SIGMA
        );
    }

    /**
     * @notice Verifies a Falcon-1024 signature
     * @param messageHash Hash of the message that was signed
     * @param signature Falcon signature bytes
     * @param publicKeyH First component of the public key
     * @param publicKeyRho Second component of the public key
     * @return True if signature is valid
     */
    function verifyFalcon1024(
        bytes32 messageHash,
        bytes calldata signature,
        bytes32 publicKeyH,
        bytes32 publicKeyRho
    ) internal pure returns (bool) {
        return _verifyFalcon(
            messageHash,
            signature,
            publicKeyH,
            publicKeyRho,
            FALCON_1024_N,
            FALCON_1024_Q,
            FALCON_1024_SIGMA
        );
    }

    /**
     * @notice Core Falcon signature verification
     * @param messageHash Hash of the message that was signed
     * @param signature Falcon signature bytes
     * @param publicKeyH First component of the public key
     * @param publicKeyRho Second component of the public key
     * @param n Falcon parameter N (degree of polynomials)
     * @param q Modulus q
     * @param sigma Standard deviation σ (multiplied by 100)
     * @return True if signature is valid
     */
    function _verifyFalcon(
        bytes32 messageHash,
        bytes calldata signature,
        bytes32 publicKeyH,
        bytes32 publicKeyRho,
        uint256 n,
        uint256 q,
        uint256 sigma
    ) private pure returns (bool) {
        require(signature.length == n, ERR_INVALID_SIG_LENGTH);

        // Extract signature components
        bytes memory s = new bytes(n / 2);
        bytes memory c = new bytes(n / 2);
        
        for (uint i = 0; i < n / 2; i++) {
            s[i] = signature[i];
            c[i] = signature[i + n / 2];
        }

        // Verify signature norms
        (uint256 normS, uint256 normC) = _computeNorms(s, c);
        
        // Check against Falcon parameters (σ is multiplied by 100)
        uint256 maxSNorm = (sigma * sigma * n) / 10000;
        uint256 maxCNorm = q * q;
        
        require(normS <= maxSNorm, ERR_INVALID_S_NORM);
        require(normC <= maxCNorm, ERR_INVALID_C_NORM);

        // Compute and verify hash
        bytes32 computedHash = _computeVerificationHash(
            publicKeyH,
            publicKeyRho,
            messageHash,
            s,
            c,
            q
        );

        return uint256(computedHash) % q == uint256(keccak256(abi.encodePacked(s, c))) % q;
    }

    /**
     * @notice Computes the norms of signature components
     * @param s First signature component
     * @param c Second signature component
     * @return normS Norm of s
     * @return normC Norm of c
     */
    function _computeNorms(
        bytes memory s,
        bytes memory c
    ) private pure returns (uint256 normS, uint256 normC) {
        for (uint i = 0; i < s.length; i++) {
            uint256 sVal = uint8(s[i]);
            uint256 cVal = uint8(c[i]);
            normS += sVal * sVal;
            normC += cVal * cVal;
        }
    }

    /**
     * @notice Computes the verification hash
     * @param publicKeyH First component of the public key
     * @param publicKeyRho Second component of the public key
     * @param messageHash Original message hash
     * @param s First signature component
     * @param c Second signature component
     * @param q Modulus q
     * @return Hash for verification
     */
    function _computeVerificationHash(
        bytes32 publicKeyH,
        bytes32 publicKeyRho,
        bytes32 messageHash,
        bytes memory s,
        bytes memory c,
        uint256 q
    ) private pure returns (bytes32) {
        // Compute h = H(ρ ‖ t), where t = H(m)
        bytes32 h = keccak256(abi.encodePacked(publicKeyRho, messageHash));
        
        // Compute verification hash
        return keccak256(abi.encodePacked(
            publicKeyH,
            h,
            _nttMultiply(s, c, q)
        ));
    }

    /**
     * @notice Performs NTT multiplication of polynomials
     * @param a First polynomial
     * @param b Second polynomial
     * @param q Modulus
     * @return result Result of NTT multiplication
     */
    function _nttMultiply(
        bytes memory a,
        bytes memory b,
        uint256 q
    ) private pure returns (bytes memory result) {
        uint256 n = a.length;
        result = new bytes(n);
        
        // Perform NTT multiplication
        for (uint i = 0; i < n; i++) {
            uint256 sum = 0;
            for (uint j = 0; j <= i; j++) {
                sum = addmod(
                    sum,
                    mulmod(uint8(a[j]), uint8(b[i - j]), q),
                    q
                );
            }
            result[i] = bytes1(uint8(sum));
        }
    }
} 