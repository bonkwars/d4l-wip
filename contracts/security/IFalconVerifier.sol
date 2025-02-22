// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IFalconVerifier
 * @author Degen4Life Team
 * @notice Interface for verifying Falcon signatures generated offline
 * @dev Defines the interface for verifying pre-generated Falcon post-quantum signatures
 * @custom:security-contact security@memeswap.exchange
 */
interface IFalconVerifier {
    /**
     * @notice Verifies a pre-generated Falcon signature
     * @param user Address of the user
     * @param signature Falcon signature bytes
     * @return True if signature is valid and hasn't been used before
     */
    function verifySignature(
        address user,
        bytes calldata signature
    ) external returns (bool);

    /**
     * @notice Checks if a user's address is verified
     * @param user Address of the user
     * @return True if the user is verified
     */
    function isVerified(address user) external view returns (bool);

    /**
     * @notice Gets the public key components for a user
     * @param user Address of the user
     * @return h First component of the public key
     * @return rho Second component of the public key
     * @return isValid Whether the public key is valid
     */
    function getPublicKey(address user) external view returns (bytes32 h, bytes32 rho, bool isValid);

    /**
     * @notice Gets the Falcon parameters used by this implementation
     * @return n Falcon parameter N (degree of polynomials)
     * @return q Modulus q
     * @return sigma Standard deviation σ
     */
    function getFalconParameters() external pure returns (uint256 n, uint256 q, uint256 sigma);
}
