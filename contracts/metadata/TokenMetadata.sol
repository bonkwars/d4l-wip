// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solmate/src/auth/Owned.sol";

/**
 * @title TokenMetadata
 * @notice Handles IPFS metadata for tokens
 */
contract TokenMetadata is Owned {
    // Events
    event MetadataUpdated(address indexed token, string ipfsCid);
    event GatewayUpdated(string newGateway);

    // State variables
    string public ipfsGateway = "https://akxipfs.pinata.cloud";
    mapping(address => string) private _tokenMetadata;

    constructor() Owned(msg.sender) {}

    /**
     * @notice Sets the metadata CID for a token
     * @param token The token address
     * @param ipfsCid The IPFS CID of the metadata
     */
    function setMetadata(address token, string calldata ipfsCid) external {
        require(msg.sender == token || msg.sender == owner, "Unauthorized");
        require(bytes(ipfsCid).length > 0, "Invalid CID");
        
        _tokenMetadata[token] = ipfsCid;
        emit MetadataUpdated(token, ipfsCid);
    }

    /**
     * @notice Updates the IPFS gateway URL
     * @param newGateway The new gateway URL
     */
    function updateGateway(string calldata newGateway) external onlyOwner {
        require(bytes(newGateway).length > 0, "Invalid gateway");
        ipfsGateway = newGateway;
        emit GatewayUpdated(newGateway);
    }

    /**
     * @notice Gets the metadata URI for a token
     * @param token The token address
     * @return The complete metadata URI
     */
    function getMetadataURI(address token) external view returns (string memory) {
        string memory cid = _tokenMetadata[token];
        require(bytes(cid).length > 0, "No metadata");
        
        return string(abi.encodePacked(ipfsGateway, "/ipfs/", cid));
    }

    /**
     * @notice Gets the raw IPFS CID for a token
     * @param token The token address
     */
    function getMetadataCID(address token) external view returns (string memory) {
        return _tokenMetadata[token];
    }
} 