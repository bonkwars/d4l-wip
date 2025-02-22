// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IAggregatorV3.sol";
import "./interfaces/IHydraCurve.sol";
import "./curve/curve.sol";

interface IPriceFeed {
    function latestRoundData() external view returns (
        uint80,
        int256,
        uint256,
        uint256,
        uint80
    );
}

/**
 * @title BonkWars
 * @notice Prediction market for meme tokens that have reached qualification threshold
 */
contract BonkWars is ReentrancyGuard, Pausable {
    // Structs
    struct Market {
        address token;
        uint256 marketCap;
        uint256 startTime;
        uint256 endTime;
        uint256 totalYes;
        uint256 totalNo;
        uint256 threshold;
        bool resolved;
        MarketType marketType;
        bytes32 outcome;
    }

    struct Position {
        uint256 amount;
        bool isYes;
        bool claimed;
    }

    struct TokenInfo {
        uint256 marketCap;
        uint256 lastUpdate;
        bool qualified;
        uint256 volume24h;
        uint256 holderCount;
        uint256 price;
        bool cexListed;
        uint256 communitySize;
        uint256 influencerScore;
        uint256 developmentScore;
        bool crossChainEnabled;
    }

    // Enums
    enum MarketType {
        MARKET_CAP,
        SOCIAL_ENGAGEMENT,
        VOLUME_MILESTONE,
        HOLDER_COUNT,
        PRICE_TARGET,
        CEX_LISTING,
        COMMUNITY_GROWTH,
        INFLUENCER_ADOPTION,
        DEVELOPMENT_MILESTONE,
        CROSS_CHAIN_EXPANSION
    }

    // State variables
    mapping(bytes32 => Market) public markets;
    mapping(bytes32 => mapping(address => Position)) public positions;
    mapping(address => TokenInfo) public tokens;
    
    uint256 public constant QUALIFICATION_THRESHOLD = 160_000 * 1e18; // $160K USD
    uint256 public constant MIN_MARKET_DURATION = 1 hours;
    uint256 public constant MAX_MARKET_DURATION = 30 days;
    
    address public immutable usdPriceFeed;
    address public immutable hydraCurve;
    
    // Social engagement tracking
    mapping(address => mapping(bytes32 => bool)) private socialActions;
    mapping(address => uint256) public socialActionCount;
    
    // Milestone tracking
    mapping(address => mapping(uint256 => bool)) public milestones;
    
    // Add these state variables
    address public factory;
    address public oracle;
    
    // Events
    event MarketCreated(
        bytes32 indexed marketId,
        address indexed token,
        uint256 threshold,
        uint256 startTime,
        uint256 endTime,
        MarketType marketType
    );
    
    event PositionTaken(
        bytes32 indexed marketId,
        address indexed user,
        uint256 amount,
        bool isYes
    );
    
    event MarketResolved(
        bytes32 indexed marketId,
        bytes32 outcome,
        uint256 totalYes,
        uint256 totalNo
    );
    
    event TokenQualified(address indexed token, uint256 marketCap);
    event RewardsClaimed(bytes32 indexed marketId, address indexed user, uint256 amount);
    event SocialActionRecorded(
        address indexed token,
        string actionType,
        string proof,
        uint256 timestamp
    );
    
    event MilestoneRecorded(
        address indexed token,
        uint256 indexed milestoneId,
        string proof,
        uint256 timestamp
    );

    constructor(address _hydraCurve, address _usdPriceFeed, address _factory, address _oracle) {
        require(_hydraCurve != address(0), "Invalid HydraCurve address");
        require(_usdPriceFeed != address(0), "Invalid USD price feed address");
        require(_factory != address(0), "Invalid factory address");
        require(_oracle != address(0), "Invalid oracle address");
        
        hydraCurve = _hydraCurve;
        usdPriceFeed = _usdPriceFeed;
        factory = _factory;
        oracle = _oracle;
    }

    /**
     * @notice Creates a new prediction market
     * @param token The meme token address
     * @param threshold The target threshold for the prediction
     * @param duration Market duration in seconds
     * @param marketType Type of prediction market
     */
    function createMarket(
        address token,
        uint256 threshold,
        uint256 duration,
        MarketType marketType
    ) external whenNotPaused returns (bytes32 marketId) {
        require(tokens[token].qualified, "Token not qualified");
        require(duration >= MIN_MARKET_DURATION && duration <= MAX_MARKET_DURATION, "Invalid duration");
        
        marketId = keccak256(abi.encodePacked(token, block.timestamp, marketType));
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;
        
        markets[marketId] = Market({
            token: token,
            marketCap: tokens[token].marketCap,
            startTime: startTime,
            endTime: endTime,
            totalYes: 0,
            totalNo: 0,
            threshold: threshold,
            resolved: false,
            marketType: marketType,
            outcome: bytes32(0)
        });
        
        emit MarketCreated(marketId, token, threshold, startTime, endTime, marketType);
    }

    /**
     * @notice Takes a position in a prediction market
     * @param marketId The market identifier
     * @param amount Amount to stake
     * @param isYes Whether betting on yes
     */
    function takePosition(
        bytes32 marketId,
        uint256 amount,
        bool isYes
    ) external nonReentrant whenNotPaused {
        Market storage market = markets[marketId];
        require(block.timestamp >= market.startTime, "Market not started");
        require(block.timestamp < market.endTime, "Market ended");
        require(!market.resolved, "Market resolved");
        
        if (isYes) {
            market.totalYes += amount;
        } else {
            market.totalNo += amount;
        }
        
        Position storage position = positions[marketId][msg.sender];
        position.amount += amount;
        position.isYes = isYes;
        
        emit PositionTaken(marketId, msg.sender, amount, isYes);
        
        require(IERC20(market.token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    /**
     * @notice Resolves a prediction market
     * @param marketId The market identifier
     */
    function resolveMarket(bytes32 marketId) external whenNotPaused {
        Market storage market = markets[marketId];
        require(block.timestamp >= market.endTime, "Market not ended");
        require(!market.resolved, "Already resolved");
        
        bool result = _resolveMarket(marketId);
        
        market.resolved = true;
        market.outcome = bytes32(uint256(result ? 1 : 0));
        
        emit MarketResolved(marketId, market.outcome, market.totalYes, market.totalNo);
    }

    /**
     * @notice Claims rewards for a resolved market
     * @param marketId The market identifier
     */
    function claimRewards(bytes32 marketId) external nonReentrant whenNotPaused {
        Market storage market = markets[marketId];
        require(market.resolved, "Not resolved");
        
        Position storage position = positions[marketId][msg.sender];
        require(!position.claimed, "Already claimed");
        require(position.amount > 0, "No position");
        
        bool won = (market.outcome == bytes32(uint256(1))) == position.isYes;
        uint256 reward = _calculateReward(market, position, won);
        
        position.claimed = true;
        
        emit RewardsClaimed(marketId, msg.sender, reward);
        
        require(IERC20(market.token).transfer(msg.sender, reward), "Transfer failed");
    }

    /**
     * @notice Updates token market cap and qualification status
     * @param token The token address
     */
    function updateTokenStatus(address token) external {
        uint256 marketCap = _getMarketCap(token);
        TokenInfo storage info = tokens[token];
        
        info.marketCap = marketCap;
        info.lastUpdate = block.timestamp;
        
        bool wasQualified = info.qualified;
        bool isQualified = marketCap >= QUALIFICATION_THRESHOLD;
        
        if (!wasQualified && isQualified) {
            info.qualified = true;
            emit TokenQualified(token, marketCap);
        } else if (wasQualified && !isQualified) {
            info.qualified = false;
        }
    }

    /**
     * @notice Records a social action for a token
     * @param token The token address
     * @param actionType The type of social action (e.g., "tweet", "like", etc.)
     * @param proof Proof of the social action
     */
    function recordSocialAction(
        address token,
        string calldata actionType,
        string calldata proof
    ) external whenNotPaused {
        bytes32 actionHash = keccak256(abi.encodePacked(actionType, proof));
        require(!socialActions[token][actionHash], "Action already recorded");
        
        socialActions[token][actionHash] = true;
        socialActionCount[token]++;
        
        emit SocialActionRecorded(token, actionType, proof, block.timestamp);
    }

    /**
     * @notice Records a milestone achievement for a token
     * @param token The token address
     * @param milestoneId The ID of the milestone
     * @param proof Proof of the milestone achievement
     */
    function recordMilestone(
        address token,
        uint256 milestoneId,
        string calldata proof
    ) external whenNotPaused {
        require(!milestones[token][milestoneId], "Milestone already recorded");
        
        milestones[token][milestoneId] = true;
        
        emit MilestoneRecorded(token, milestoneId, proof, block.timestamp);
    }

    // Internal functions
    function _resolveMarket(bytes32 marketId) internal view returns (bool) {
        Market storage market = markets[marketId];
        TokenInfo storage info = tokens[market.token];

        if (market.marketType == MarketType.MARKET_CAP) {
            return info.marketCap >= market.threshold;
        } else if (market.marketType == MarketType.SOCIAL_ENGAGEMENT) {
            return socialActionCount[market.token] >= market.threshold;
        } else if (market.marketType == MarketType.VOLUME_MILESTONE) {
            return info.volume24h >= market.threshold;
        } else if (market.marketType == MarketType.HOLDER_COUNT) {
            return info.holderCount >= market.threshold;
        } else if (market.marketType == MarketType.PRICE_TARGET) {
            return info.price >= market.threshold;
        } else if (market.marketType == MarketType.CEX_LISTING) {
            return info.cexListed;
        } else if (market.marketType == MarketType.COMMUNITY_GROWTH) {
            return info.communitySize >= market.threshold;
        } else if (market.marketType == MarketType.INFLUENCER_ADOPTION) {
            return info.influencerScore >= market.threshold;
        } else if (market.marketType == MarketType.DEVELOPMENT_MILESTONE) {
            return info.developmentScore >= market.threshold;
        } else if (market.marketType == MarketType.CROSS_CHAIN_EXPANSION) {
            return info.crossChainEnabled;
        }
        return false;
    }
    
    function _calculateReward(
        Market storage market,
        Position storage position,
        bool won
    ) internal view returns (uint256) {
        if (!won) return 0;
        
        uint256 totalPool = market.totalYes + market.totalNo;
        uint256 winningPool = position.isYes ? market.totalYes : market.totalNo;
        
        return (position.amount * totalPool) / winningPool;
    }
    
    function _getTokenPrice(address token) internal view returns (uint256) {
        uint256 supply = IERC20(token).totalSupply();
        uint256 tokenPrice = IHydraCurve(hydraCurve).calculatePrice(token, supply);
        uint256 usdPrice = _getUSDPrice();
        require(tokenPrice > 0, "Invalid token price");
        require(usdPrice > 0, "Invalid USD price");
        // tokenPrice is in 18 decimals, usdPrice is in 8 decimals
        // We want the result in USD (8 decimals)
        return (tokenPrice * usdPrice) / 1e18;
    }
    
    function _getUSDPrice() internal view returns (uint256) {
        (, int256 price, , , ) = IPriceFeed(usdPriceFeed).latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    }

    function _getMarketCap(address token) internal view returns (uint256) {
        uint256 price = _getTokenPrice(token);
        uint256 supply = IERC20(token).totalSupply();
        // Price is in USD (8 decimals), supply is in 18 decimals
        // We want the result in USD (18 decimals)
        return (price * supply) / 1e8;
    }

    // Admin functions
    function pause() external {
        _pause();
    }
    
    function unpause() external {
        _unpause();
    }

    // Update functions for token info
    function updateVolume(address token, uint256 volume) external {
        require(msg.sender == factory || msg.sender == oracle, "Unauthorized");
        tokens[token].volume24h = volume;
    }

    function updateHolderCount(address token, uint256 count) external {
        require(msg.sender == factory || msg.sender == oracle, "Unauthorized");
        tokens[token].holderCount = count;
    }

    function updatePrice(address token, uint256 price) external {
        require(msg.sender == factory || msg.sender == oracle, "Unauthorized");
        tokens[token].price = price;
    }

    function updateCEXListing(address token, bool listed) external {
        require(msg.sender == factory || msg.sender == oracle, "Unauthorized");
        tokens[token].cexListed = listed;
    }

    function updateCommunitySize(address token, uint256 size) external {
        require(msg.sender == factory || msg.sender == oracle, "Unauthorized");
        tokens[token].communitySize = size;
    }

    function updateInfluencerScore(address token, uint256 score) external {
        require(msg.sender == factory || msg.sender == oracle, "Unauthorized");
        tokens[token].influencerScore = score;
    }

    function updateDevelopmentScore(address token, uint256 score) external {
        require(msg.sender == factory || msg.sender == oracle, "Unauthorized");
        tokens[token].developmentScore = score;
    }

    function updateCrossChainStatus(address token, bool enabled) external {
        require(msg.sender == factory || msg.sender == oracle, "Unauthorized");
        tokens[token].crossChainEnabled = enabled;
    }
} 