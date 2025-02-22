// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IUserProfile.sol";

contract MockUserProfile is IUserProfile {
    mapping(address => address[]) public userTokens;
    uint256 public totalUsers;

    function recordTokenCreation(address creator, address token) external {
        userTokens[creator].push(token);
        totalUsers++;
    }

    function getUserTokens(address user) external view returns (address[] memory) {
        return userTokens[user];
    }

    function initialize(address token, address registry) external {
        // No initialization needed for mock
    }
} 