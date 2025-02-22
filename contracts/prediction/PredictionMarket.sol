// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../registry/ContractRegistry.sol";

contract PredictionMarket is AccessControl, ReentrancyGuard {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    
    ContractRegistry public immutable registry;
    
    struct Market {
        address token;
        uint256 startTime;
        uint256 endTime;
        uint256 resolutionTime;
        uint256 totalYesAmount;
        uint256 totalNoAmount;
        bool resolved;
        bool outcome;
        string description;
    }
    
    struct Position {
        uint256 yesAmount;
        uint256 noAmount;
        bool claimed;
    }
    
    // Market ID => Market
    mapping(bytes32 => Market) public markets;
    // Market ID => User => Position
    mapping(bytes32 => mapping(address => Position)) public positions;
    
    // Events
    event MarketCreated(bytes32 indexed marketId, address indexed token, string description);
    event PositionTaken(bytes32 indexed marketId, address indexed user, bool isYes, uint256 amount);
    event MarketResolved(bytes32 indexed marketId, bool outcome);
    event RewardsClaimed(bytes32 indexed marketId, address indexed user, uint256 amount);
    
    constructor(address _registry) {
        require(_registry != address(0), "Invalid registry");
        registry = ContractRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }
    
    function createMarket(
        address token,
        uint256 duration,
        string calldata description
    ) external returns (bytes32) {
        require(duration > 0, "Invalid duration");
        
        bytes32 marketId = keccak256(abi.encodePacked(
            token,
            block.timestamp,
            description
        ));
        
        require(markets[marketId].token == address(0), "Market exists");
        
        markets[marketId] = Market({
            token: token,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            resolutionTime: 0,
            totalYesAmount: 0,
            totalNoAmount: 0,
            resolved: false,
            outcome: false,
            description: description
        });
        
        emit MarketCreated(marketId, token, description);
        return marketId;
    }
    
    function takePosition(
        bytes32 marketId,
        bool isYes,
        uint256 amount
    ) external nonReentrant {
        Market storage market = markets[marketId];
        require(market.token != address(0), "Market not found");
        require(block.timestamp < market.endTime, "Market ended");
        require(!market.resolved, "Market resolved");
        require(amount > 0, "Invalid amount");
        
        IERC20(market.token).transferFrom(msg.sender, address(this), amount);
        
        Position storage position = positions[marketId][msg.sender];
        if (isYes) {
            position.yesAmount += amount;
            market.totalYesAmount += amount;
        } else {
            position.noAmount += amount;
            market.totalNoAmount += amount;
        }
        
        emit PositionTaken(marketId, msg.sender, isYes, amount);
    }
    
    function resolveMarket(
        bytes32 marketId,
        bool outcome
    ) external onlyRole(ORACLE_ROLE) {
        Market storage market = markets[marketId];
        require(market.token != address(0), "Market not found");
        require(block.timestamp >= market.endTime, "Market not ended");
        require(!market.resolved, "Already resolved");
        
        market.resolved = true;
        market.outcome = outcome;
        market.resolutionTime = block.timestamp;
        
        emit MarketResolved(marketId, outcome);
    }
    
    function claimRewards(bytes32 marketId) external nonReentrant {
        Market storage market = markets[marketId];
        require(market.resolved, "Not resolved");
        
        Position storage position = positions[marketId][msg.sender];
        require(!position.claimed, "Already claimed");
        require(position.yesAmount > 0 || position.noAmount > 0, "No position");
        
        uint256 reward;
        if (market.outcome) {
            // Yes won
            if (position.yesAmount > 0) {
                reward = position.yesAmount + (position.yesAmount * market.totalNoAmount) / market.totalYesAmount;
            }
        } else {
            // No won
            if (position.noAmount > 0) {
                reward = position.noAmount + (position.noAmount * market.totalYesAmount) / market.totalNoAmount;
            }
        }
        
        require(reward > 0, "No rewards");
        position.claimed = true;
        
        IERC20(market.token).transfer(msg.sender, reward);
        emit RewardsClaimed(marketId, msg.sender, reward);
    }
    
    function getMarket(bytes32 marketId) external view returns (Market memory) {
        return markets[marketId];
    }
    
    function getPosition(
        bytes32 marketId,
        address user
    ) external view returns (Position memory) {
        return positions[marketId][user];
    }
} 