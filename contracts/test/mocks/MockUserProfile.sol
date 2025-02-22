// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/IUserProfile.sol";
import "../../tokens/UserToken.sol";
contract MockUserProfile is IUserProfile {
    mapping(address => bool) public isRegistered;
    mapping(address => address[]) public userTokens;
    uint256 public override totalUsers;

    function recordTokenCreation(address creator, address token) external override {
        if (!isRegistered[creator]) {
            isRegistered[creator] = true;
            totalUsers++;
        }
        userTokens[creator].push(token);
    
    }

    function getTokenSocialData(address token) external pure override returns (bytes memory) {
        return "";
    }

    function getUserPortfolio(address user) external view override returns (address[] memory) {
        return userTokens[user];
    }

    function getReputation(address user) external pure override returns (uint256) {
        return 100;
    }

    function isVerified(address user) external pure override returns (bool) {
        return true;
    }

    function updateLiquidityStats(
        address user,
        address token,
        uint256 amount
    ) external override {
        // No-op for mock
    }

    function unlockAchievement(address user, uint256 achievementId) external override {
        // No-op for mock
    }
} 