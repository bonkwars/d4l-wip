// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ITokenComponentFactory.sol";
import "./MockERC20.sol";
import "./MockSecurityModule.sol";
import "./MockSocialModule.sol";

contract MockTokenComponentFactory {
    function createTokenComponents(address token) external returns (
        address antiBot,
        address antiRugPull,
        address liquidityModule,
        address securityModule
    ) {
        // Create mock components
        antiBot = address(new MockERC20("AntiBot", "AB", 0));
        antiRugPull = address(new MockERC20("AntiRugPull", "ARP", 0));
        liquidityModule = address(new MockERC20("LiquidityModule", "LM", 0));
        securityModule = address(new MockSecurityModule());
        
        // Create social module
        address socialModule = address(new MockSocialModule());
        
        return (antiBot, antiRugPull, liquidityModule, securityModule);
    }
} 