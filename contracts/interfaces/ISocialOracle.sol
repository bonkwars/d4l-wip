// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISocialOracle {
    function recordEngagement(address token, bytes memory socialData) external;
} 