// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IUserProfile.sol";
import "./interfaces/IPoolController.sol";

contract Degen4LifeView {
    address public userProfile;
    address public poolController;
    
    struct UserView {
        address[] portfolio;
        uint256 reputationScore;
        address[] activePools;
        bool isVerified;
    }

    constructor(address _userProfile, address _poolController) {
        userProfile = _userProfile;
        poolController = _poolController;
    }

    function getUserPortfolio(address user) external view returns (UserView memory) {
        return UserView({
            portfolio: IUserProfile(userProfile).getUserPortfolio(user),
            
            reputationScore: IUserProfile(userProfile).getReputation(user),
            activePools: IPoolController(poolController).getUserPools(user),
            isVerified: IUserProfile(userProfile).isVerified(user)
        });
    }
} 