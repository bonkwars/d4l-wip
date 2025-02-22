// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/mocks/MockERC20.sol";

contract SnipingBot {
    address public token;
    
    constructor(address _token) {
        token = _token;
    }

    function executeSnipingAttack(uint256 amount, address[] calldata targets) external {
        uint256 amountPerTarget = amount / targets.length;
        for (uint i = 0; i < targets.length; i++) {
            MockERC20(token).transfer(targets[i], amountPerTarget);
        }
    }
} 