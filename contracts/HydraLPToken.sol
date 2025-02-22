// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract HydraLPToken is ERC20Votes, ERC20Permit {
    address public immutable amm;
    
    constructor() 
        ERC20("Hydra LP Token", "HLP")
        ERC20Permit("Hydra LP Token") 
    {
        amm = msg.sender;
    }
    
    function mint(address to, uint256 amount) external {
        require(msg.sender == amm, "Unauthorized");
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external {
        require(msg.sender == amm, "Unauthorized");
        _burn(from, amount);
    }


    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    function nonces(address owner) public view override(ERC20Permit,  Nonces) returns (uint256) {
        return super.nonces(owner);
    }
} 