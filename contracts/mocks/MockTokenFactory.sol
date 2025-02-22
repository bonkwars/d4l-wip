// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ITokenFactory.sol";
import "./MockERC20.sol";

contract MockTokenFactory {
    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address initialHolder,
        uint256 feePercent
    ) external returns (address) {
        MockERC20 token = new MockERC20(name, symbol, 0);
        token.mint(initialHolder, initialSupply);
        return address(token);
    }

    function getAllTokens() external pure returns (address[] memory) {
        address[] memory tokens = new address[](0);
        return tokens;
    }
} 