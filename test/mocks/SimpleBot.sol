// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/mocks/MockERC20.sol";

contract SimpleBot {
    address public token;
    
    constructor(address _token) {
        token = _token;
    }

    function executeSimpleAttack(uint256 amount) external {
        MockERC20(token).transfer(msg.sender, amount);
    }
} 