// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AchievementNFT is ERC721, Ownable {
    constructor(string memory name, string memory symbol, address initialOwner) 
        ERC721(name, symbol)
        Ownable(initialOwner)
    {}

    function safeMint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }
} 