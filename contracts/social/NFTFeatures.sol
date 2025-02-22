// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./TokenGating.sol";
import "./AchievementNFT.sol";
import "./BadgeNFT.sol";

contract NFTFeatures is Initializable, OwnableUpgradeable, TokenGating {
    struct Achievement {
        string name;
        string description;
        string metadata;        // IPFS hash
        uint256 requiredScore;
        bool active;
    }

    struct Badge {
        string name;
        string metadata;        // IPFS hash
        uint256 maxSupply;
        uint256 minted;
        bool transferable;
    }

    // NFT contracts
    AchievementNFT public achievementNFT;
    BadgeNFT public badgeNFT;

    // Mappings
    mapping(uint256 => Achievement) public achievements;
    mapping(uint256 => Badge) public badges;
    mapping(address => uint256[]) public userAchievements;
    mapping(address => mapping(uint256 => uint256)) public userBadges;

    // Events
    event AchievementCreated(uint256 indexed id, string name, uint256 requiredScore);
    event AchievementUnlocked(address indexed user, uint256 indexed achievementId);
    event BadgeCreated(uint256 indexed id, string name, uint256 maxSupply);
    event BadgeAwarded(address indexed user, uint256 indexed badgeId, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _achievementNFT, address _badgeNFT) external initializer {
        __Ownable_init(msg.sender);
        achievementNFT = AchievementNFT(_achievementNFT);
        badgeNFT = BadgeNFT(_badgeNFT);
    }

    function createAchievement(
        string calldata name,
        string calldata description,
        string calldata metadata,
        uint256 requiredScore
    ) external returns (uint256 achievementId) {
        achievementId = uint256(keccak256(abi.encodePacked(name, block.timestamp)));
        
        achievements[achievementId] = Achievement({
            name: name,
            description: description,
            metadata: metadata,
            requiredScore: requiredScore,
            active: true
        });

        emit AchievementCreated(achievementId, name, requiredScore);
    }

    function createBadge(
        string calldata name,
        string calldata metadata,
        uint256 maxSupply,
        bool transferable
    ) external returns (uint256 badgeId) {
        badgeId = uint256(keccak256(abi.encodePacked(name, block.timestamp)));
        
        badges[badgeId] = Badge({
            name: name,
            metadata: metadata,
            maxSupply: maxSupply,
            minted: 0,
            transferable: transferable
        });

        emit BadgeCreated(badgeId, name, maxSupply);
    }

    function checkAndAwardAchievements(address user, uint256 score) external {
        for (uint256 i = 0; i < userAchievements[user].length; i++) {
            uint256 achievementId = userAchievements[user][i];
            Achievement memory achievement = achievements[achievementId];
            
            if (achievement.active && score >= achievement.requiredScore) {
                achievementNFT.safeMint(user, achievementId);
                emit AchievementUnlocked(user, achievementId);
            }
        }
    }

    function awardBadge(
        address user,
        uint256 badgeId,
        uint256 amount
    ) external {
        Badge storage badge = badges[badgeId];
        require(badge.minted + amount <= badge.maxSupply, "Exceeds max supply");
        
        badge.minted += amount;
        userBadges[user][badgeId] += amount;
        badgeNFT.mint(user, badgeId, amount, "");
        
        emit BadgeAwarded(user, badgeId, amount);
    }
} 