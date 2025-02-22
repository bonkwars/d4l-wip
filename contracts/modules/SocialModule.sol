// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseModule.sol";
import "../interfaces/IUserProfile.sol";
import "../interfaces/ISocialOracle.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract SocialModule is BaseModule {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Constants for action types and points (packed into single storage slot)
    struct ActionPoints {
        uint64 post;
        uint64 comment;
        uint64 share;
        uint64 like;
        uint64 tokenCreation;
    }
    
    ActionPoints public points;

    // Roles (packed into single storage slot)
    bytes32 private constant SOCIAL_ADMIN = keccak256("SOCIAL_ADMIN");
    bytes32 private constant CONTENT_MODERATOR = keccak256("CONTENT_MODERATOR");

    // Optimized structs for better packing
    struct TokenGate {
        address token;          // 20 bytes
        uint96 minAmount;       // 12 bytes
        uint32 tokenId;         // 4 bytes
        uint8 tokenType;        // 1 byte
        bool active;            // 1 byte
        uint32 duration;        // 4 bytes
    }

    struct Achievement {
        string name;            // 32 bytes
        uint32 requiredScore;   // 4 bytes
        uint32 rewardPoints;    // 4 bytes
        bytes32 category;       // 32 bytes
        bool active;            // 1 byte
        mapping(address => bool) unlocked; // User unlock status
    }

    struct UserStats {
        uint32 totalPosts;      // 4 bytes
        uint32 totalComments;   // 4 bytes
        uint32 totalShares;     // 4 bytes
        uint32 totalLikes;      // 4 bytes
        uint32 totalTokenCreations; // 4 bytes
        uint96 reputation;      // 12 bytes
        uint32 lastActionTime;  // 4 bytes
    }

    // Storage optimization using EnumerableSet
    mapping(bytes32 => TokenGate) private _gates;
    mapping(bytes32 => Achievement) private _achievements;
    mapping(address => UserStats) private _stats;
    
    // Sets for efficient iteration
    EnumerableSet.Bytes32Set private _achievementIds;
    EnumerableSet.Bytes32Set private _gateIds;
    EnumerableSet.AddressSet private _bannedUsers;
    EnumerableSet.Bytes32Set private _bannedContent;

    // Events
    event TokenGateCreated(bytes32 indexed gateId, address indexed token, uint96 minAmount);
    event TokenGateUpdated(bytes32 indexed gateId, bool active);
    event AchievementCreated(bytes32 indexed achievementId, string name, uint32 requiredScore);
    event AchievementUnlocked(address indexed user, bytes32 indexed achievementId, uint32 rewardPoints);
    event ContentModerated(bytes32 indexed contentId, bool banned);
    event UserBanned(address indexed user, bool banned);
    event SocialAction(
        address indexed user,
        bytes32 indexed actionType,
        bytes32 contentId,
        uint32 points
    );

    function initialize(address _registry) external virtual initializer {
        __BaseModule_init(_registry);
        _grantRole(SOCIAL_ADMIN, msg.sender);
        _grantRole(CONTENT_MODERATOR, msg.sender);

        points = ActionPoints({
            post: 100,
            comment: 50,
            share: 75,
            like: 25,
            tokenCreation: 1000
        });
    }

    // Token Gating Functions
    function createTokenGate(
        address token,
        uint256 minHoldAmount,
        uint256 minHoldDuration,
        uint256 requiredLevel,
        bool requireVerification,
        bool enableTrading,
        bool enableStaking
    ) virtual external;

    function updateTokenGate(
        bytes32 gateId,
        bool active
    ) external onlyRole(SOCIAL_ADMIN) {
        require(_gates[gateId].token != address(0), "Gate not found");
        _gates[gateId].active = active;
        emit TokenGateUpdated(gateId, active);
    }

    function checkGateAccess(
        address user,
        bytes32 gateId
    ) public view returns (bool) {
        TokenGate memory gate = _gates[gateId];
        if (!gate.active) return false;

        if (gate.tokenType == 1) {
            return IERC20(gate.token).balanceOf(user) >= gate.minAmount;
        } else if (gate.tokenType == 2) {
            return IERC721(gate.token).balanceOf(user) >= gate.minAmount;
        } else if (gate.tokenType == 3) {
            return IERC1155(gate.token).balanceOf(user, gate.tokenId) >= gate.minAmount;
        }
        return false;
    }

    // Achievement Functions
    function createAchievement(
        bytes32 achievementId,
        string calldata name,
        uint32 requiredScore,
        uint32 rewardPoints,
        bytes32 category
    ) external onlyRole(SOCIAL_ADMIN) {
        require(bytes(name).length > 0, "Invalid name");
        require(requiredScore > 0, "Invalid score");
        require(!_achievementIds.contains(achievementId), "Achievement exists");

        Achievement storage achievement = _achievements[achievementId];
        achievement.name = name;
        achievement.requiredScore = requiredScore;
        achievement.rewardPoints = rewardPoints;
        achievement.category = category;
        achievement.active = true;

        _achievementIds.add(achievementId);
        emit AchievementCreated(achievementId, name, requiredScore);
    }

    // Social Actions with optimized storage
    function recordAction(
        bytes32 actionType,
        bytes32 contentId,
        bytes calldata data
    ) external whenNotPaused {
        require(!_bannedUsers.contains(msg.sender), "User banned");
        require(!_bannedContent.contains(contentId), "Content banned");

        UserStats storage stats = _stats[msg.sender];
        uint32 actionPoints;

        if(actionType == keccak256("TOKEN_CREATION")){
            actionPoints = uint32(points.tokenCreation);
            stats.totalTokenCreations++;
        } else if (actionType == keccak256("POST")) {
            actionPoints = uint32(points.post);
            stats.totalPosts++;
        } else if (actionType == keccak256("COMMENT")) {
            actionPoints = uint32(points.comment);
            stats.totalComments++;
        } else if (actionType == keccak256("SHARE")) {
            actionPoints = uint32(points.share);
            stats.totalShares++;
        } else if (actionType == keccak256("LIKE")) {
            actionPoints = uint32(points.like);
            stats.totalLikes++;
        } else {
            revert("Invalid action");
        }

        stats.reputation += actionPoints;
        stats.lastActionTime = uint32(block.timestamp);

        // Record engagement and check achievements
        address socialOracle = getContractAddress(keccak256("SOCIAL_ORACLE"));
        ISocialOracle(socialOracle).recordEngagement(msg.sender, data);
        _checkAchievements(msg.sender, stats.reputation);

        emit SocialAction(msg.sender, actionType, contentId, actionPoints);
    }

    // Optimized achievement checking
    function _checkAchievements(address user, uint96 reputation) internal {
        uint256 length = _achievementIds.length();
        for (uint256 i = 0; i < length; i++) {
            bytes32 achievementId = _achievementIds.at(i);
            Achievement storage achievement = _achievements[achievementId];
            
            if (achievement.active && 
                !achievement.unlocked[user] && 
                reputation >= achievement.requiredScore) {
                
                achievement.unlocked[user] = true;
                _stats[user].reputation += achievement.rewardPoints;
                
                // Convert bytes32 achievementId to uint256 starting from ACHIEVEMENT_START_ID (100)
                uint256 profileAchievementId = uint256(achievementId) % 1000000 + 100;
                
                // Unlock achievement in UserProfile contract
                address userProfile = getContractAddress(registry.USER_PROFILE());
                IUserProfile(userProfile).unlockAchievement(user, profileAchievementId);
                
                emit AchievementUnlocked(
                    user,
                    achievementId,
                    achievement.rewardPoints
                );
            }
        }
    }

    // Optimized moderation functions
    function moderateContent(bytes32 contentId, bool banned) external onlyRole(CONTENT_MODERATOR) {
        if (banned) {
            _bannedContent.add(contentId);
        } else {
            _bannedContent.remove(contentId);
        }
        emit ContentModerated(contentId, banned);
    }

    function banUser(address user, bool banned) external onlyRole(CONTENT_MODERATOR) {
        if (banned) {
            _bannedUsers.add(user);
        } else {
            _bannedUsers.remove(user);
        }
        emit UserBanned(user, banned);
    }

    // View functions with pagination support
    function getAchievements(uint256 offset, uint256 limit) 
        external 
        view 
        returns (
            bytes32[] memory ids,
            string[] memory names,
            uint32[] memory scores
        ) 
    {
        uint256 length = _achievementIds.length();
        uint256 end = offset + limit > length ? length : offset + limit;
        uint256 size = end - offset;
        
        ids = new bytes32[](size);
        names = new string[](size);
        scores = new uint32[](size);
        
        for (uint256 i = offset; i < end; i++) {
            bytes32 id = _achievementIds.at(i);
            Achievement storage achievement = _achievements[id];
            ids[i - offset] = id;
            names[i - offset] = achievement.name;
            scores[i - offset] = achievement.requiredScore;
        }
    }

    function getUserStats(address user) external view returns (UserStats memory) {
        return _stats[user];
    }
} 