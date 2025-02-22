// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IVersionController {
    function proposeUpgrade(address newImplementation, string calldata releaseNotes) external returns (bool);
} 