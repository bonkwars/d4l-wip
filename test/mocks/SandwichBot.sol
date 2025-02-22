// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/mocks/MockERC20.sol";

contract SandwichBot {
    address public token;
    
    constructor(address _token) {
        token = _token;
    }

    function executeSandwichAttack(uint256 amount, address target) external {
        // Front-run
        MockERC20(token).transfer(target, amount / 2);
        
        // Back-run
        MockERC20(token).transfer(msg.sender, amount / 2);
    }
} 