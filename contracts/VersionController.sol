// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VersionController {
    struct Version {
        bytes32 versionHash;
        address implementation;
        uint256 timestamp;
        string releaseNotes;
    }
    
    mapping(uint256 => Version) public versions;
    uint256 public currentVersion;
    
    function proposeUpgrade(
        address newImplementation,
        string calldata releaseNotes
    ) external {
        require(newImplementation != address(0), "Invalid implementation");
        bytes32 hash = keccak256(abi.encodePacked(newImplementation));
        versions[++currentVersion] = Version(
            hash,
            newImplementation,
            block.timestamp,
            releaseNotes
        );
    }
    
    function validateUpgrade(address newImpl) public view returns (bool) {
        require(newImpl != address(0), "Invalid implementation");
        return versions[currentVersion].implementation == newImpl;
    }
} 