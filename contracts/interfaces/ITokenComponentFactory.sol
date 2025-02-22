// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenComponentFactory {
    function createTokenComponents(address token) external returns (
        address antiBot,
        address antiRugPull,
        address liquidityModule,
        address securityModule
    );
    
    function getTokenComponents(address token) external view returns (
        address antiBot,
        address antiRugPull,
        address liquidityModule,
        address securityModule
    );
} 