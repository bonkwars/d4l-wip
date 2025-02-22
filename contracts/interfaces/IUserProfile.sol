// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUserProfile {
    function recordTokenCreation(address creator, address token) external;
    function totalUsers() external view returns (uint256);
    function getTokenSocialData(address token) external view returns (bytes memory);
    function getUserPortfolio(address user) external view returns (address[] memory);
    function getReputation(address user) external view returns (uint256);
    function isVerified(address user) external view returns (bool);
    function updateLiquidityStats(
        address user,
        address token,
        uint256 amount
    ) external;
    function unlockAchievement(address user, uint256 achievementId) external;
} 