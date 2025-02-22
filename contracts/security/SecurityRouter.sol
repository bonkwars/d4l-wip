// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IAntiBot.sol";
import "../interfaces/IAntiRugPull.sol";
import "../interfaces/IUserProfile.sol";

contract SecurityRouter {
    address public controller;

    function validateTrade(
        address token,
        address trader,
        uint256 amount,
        bool isBuy
    ) external returns (bool) {
        require(IAntiBot(controller).validateTrade(trader, amount, isBuy),
        
            "AntiBot: Suspicious activity");
        require(IAntiRugPull(controller).checkSellLimit(token, amount),
            "AntiRugPull: Sell limit exceeded");
        require(IUserProfile(controller).isVerified(trader),
            "User not verified");
        return true;
    }
} 