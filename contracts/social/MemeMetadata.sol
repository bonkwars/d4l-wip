// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../factory/TokenFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MemeMetadata is Ownable {
    address public immutable factory;

    constructor(address _factory) Ownable(msg.sender) {
        require(_factory != address(0), "Invalid factory");
        factory = _factory;
    }

    struct MemeData {
        string name;
        string description;
        string imageUrl;
        string website;
        string telegram;
        string twitter;
        uint256 createdAt;
        uint256 holderCount;
        uint256 marketCap;
        bool verified;
    }
    
    mapping(address => MemeData) public memeData;
    
    event MemeDataUpdated(address indexed token, string description);
    event MemeVerified(address indexed token, bool verified);
    event MarketDataUpdated(address indexed token, uint256 holderCount, uint256 marketCap);
    
    mapping(address => bool) public verifiers;
    
    uint256 private constant MAX_STRING_LENGTH = 1000;
    mapping(address => uint256) private lastUpdateTime;
    uint256 private constant UPDATE_COOLDOWN = 1 hours;
    
    function _validateString(string memory str) internal pure returns (bool) {
        return bytes(str).length <= MAX_STRING_LENGTH;
    }
    
    function addVerifier(address verifier) external onlyOwner {
        verifiers[verifier] = true;
    }
    
    function verifyMeme(address token) external {
        require(verifiers[msg.sender], "Not a verifier");
        memeData[token].verified = true;
        emit MemeVerified(token, true);
    }
    
    function updateMarketData(
        address token,
        uint256 holderCount,
        uint256 marketCap
    ) external {
        require(msg.sender == factory, "Only factory");
        MemeData storage data = memeData[token];
        data.holderCount = holderCount;
        data.marketCap = marketCap;
        emit MarketDataUpdated(token, holderCount, marketCap);
    }

    function updateMemeData(
        address token,
        string memory description,
        string memory imageUrl,
        string memory website,
        string memory telegram,
        string memory twitter
    ) external {
        require(IERC20(token).balanceOf(msg.sender) > 0, "Not token holder");
        require(block.timestamp >= lastUpdateTime[msg.sender] + UPDATE_COOLDOWN, "Too frequent");
        require(_validateString(description), "Description too long");
        require(_validateString(imageUrl), "Image URL too long");
        require(_validateString(website), "Website too long");
        require(_validateString(telegram), "Telegram too long");
        require(_validateString(twitter), "Twitter too long");
        MemeData storage data = memeData[token];
        data.description = description;
        data.imageUrl = imageUrl;
        data.website = website;
        data.telegram = telegram;
        data.twitter = twitter;
        lastUpdateTime[msg.sender] = block.timestamp;
    }
} 