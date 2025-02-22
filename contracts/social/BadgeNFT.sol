// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BadgeNFT is ERC1155, Ownable {
    constructor(string memory uri, address initialOwner) 
        ERC1155(uri)
        Ownable(initialOwner)
    {}

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwner {
        _mint(to, id, amount, data);
    }
} 