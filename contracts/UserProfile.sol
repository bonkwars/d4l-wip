// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title UserProfile
 * @dev Soulbound ERC1155 token for user profiles with achievements
 */
contract UserProfile is ERC1155, Ownable, AccessControl {
    using Strings for uint256;

    // Constants for token IDs
    uint256 public constant PROFILE_TOKEN = 1;
    uint256 public constant ACHIEVEMENT_START_ID = 100;

    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    // Extended profile types
    enum ProfileType { REGULAR, MODERATOR, ADMIN }

    // Profile data structure
    struct Profile {
        string username;
        string avatar;           // IPFS hash of profile image
        string bio;             // User biography
        uint256 level;          // User level
        uint256 experience;     // Total experience points
        uint256 reputation;     // Reputation score
        uint256 marketsCreated;
        uint256 marketsParticipated;
        uint256 winningPredictions;
        uint256 totalVolume;    // Total trading volume
        uint256 joinedDate;     // Timestamp when profile was created
        uint256[] tokenIds;     // Array of memecoin token IDs held by user
        uint256 lastActive;     // Last activity timestamp
        ProfileType profileType; // Type of profile (regular/mod/admin)
        bool isActive;          // Profile active status
        bool isOnline;          // Current online status
    }

    // Extended profile data
    struct ModeratorData {
        uint256 actionsCount;    // Number of moderation actions taken
        uint256 reportsHandled;  // Number of reports handled
        uint256 appointedAt;     // When they became moderator
        bool canBanUsers;        // Permission to ban users
        bool canModerateContent; // Permission to moderate content
    }

    struct AdminData {
        uint256 appointedAt;     // When they became admin
        bool canGrantRoles;      // Permission to grant roles
        bool canUpdateContract;  // Permission to update contract
        bool canPause;          // Permission to pause contract
    }

    // Mappings
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(uint256 => string) public achievementURIs;
    mapping(address => mapping(string => string)) public socialLinks; // User -> Platform -> Link mapping
    mapping(address => mapping(uint256 => uint256)) public tokenBalances; // User -> TokenId -> Balance
    mapping(address => ModeratorData) public moderatorData;
    mapping(address => AdminData) public adminData;
    mapping(address => bool) public bannedUsers;

    // Events
    event ProfileCreated(address indexed user, string username);
    event ProfileUpdated(address indexed user, string username);
    event AchievementUnlocked(address indexed user, uint256 indexed achievementId);
    event ReputationUpdated(address indexed user, uint256 newReputation);
    event TokenBalanceUpdated(address indexed user, uint256 indexed tokenId, uint256 newBalance);
    event OnlineStatusUpdated(address indexed user, bool isOnline);
    event UserActivity(address indexed user, uint256 timestamp);
    event ModeratorAppointed(address indexed user, uint256 timestamp);
    event AdminAppointed(address indexed user, uint256 timestamp);
    event UserBanned(address indexed user, address indexed moderator, uint256 timestamp);
    event UserUnbanned(address indexed user, address indexed moderator, uint256 timestamp);
    event ModeratorActionTaken(address indexed moderator, string actionType, uint256 timestamp);

    // Constants
    uint256 public constant ONLINE_TIMEOUT = 5 minutes;

    constructor() ERC1155("") Ownable(msg.sender) AccessControl() {
        // Set contract deployer as initial admin
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        adminData[msg.sender] = AdminData({
            appointedAt: block.timestamp,
            canGrantRoles: true,
            canUpdateContract: true,
            canPause: true
        });
    }

    /**
     * @dev Creates a new user profile (soulbound)
     * @param username The user's chosen username
     * @param avatar IPFS hash of profile image
     * @param bio User biography
     */
    function createProfile(
        string memory username,
        string memory avatar,
        string memory bio
    ) external {
        require(!bannedUsers[msg.sender], "User is banned");
        require(!hasProfile[msg.sender], "Profile already exists");
        require(bytes(username).length > 0, "Username cannot be empty");
        
        uint256 timestamp = block.timestamp;
        profiles[msg.sender] = Profile({
            username: username,
            avatar: avatar,
            bio: bio,
            level: 1,
            experience: 0,
            reputation: 0,
            marketsCreated: 0,
            marketsParticipated: 0,
            winningPredictions: 0,
            totalVolume: 0,
            joinedDate: timestamp,
            tokenIds: new uint256[](0),
            lastActive: timestamp,
            profileType: ProfileType.REGULAR,
            isActive: true,
            isOnline: true
        });

        hasProfile[msg.sender] = true;
        _mint(msg.sender, PROFILE_TOKEN, 1, "");

        emit ProfileCreated(msg.sender, username);
        emit OnlineStatusUpdated(msg.sender, true);
        emit UserActivity(msg.sender, timestamp);
    }

    /**
     * @dev Updates user profile data
     * @param username New username (if empty, keep existing)
     * @param avatar New avatar URI (if empty, keep existing)
     * @param bio New bio (if empty, keep existing)
     */
    function updateProfile(
        string memory username,
        string memory avatar,
        string memory bio
    ) external {
        require(hasProfile[msg.sender], "Profile does not exist");
        
        Profile storage profile = profiles[msg.sender];
        
        if (bytes(username).length > 0) {
            profile.username = username;
        }
        if (bytes(avatar).length > 0) {
            profile.avatar = avatar;
        }
        if (bytes(bio).length > 0) {
            profile.bio = bio;
        }
        
        emit ProfileUpdated(msg.sender, username);
    }

    /**
     * @dev Updates user reputation (only callable by owner/BonkWars contract)
     * @param user User address
     * @param newReputation New reputation score
     */
    function updateReputation(address user, uint256 newReputation) external onlyOwner {
        require(hasProfile[user], "Profile does not exist");
        profiles[user].reputation = newReputation;
        emit ReputationUpdated(user, newReputation);
    }

    /**
     * @dev Unlocks an achievement for a user
     * @param user User address
     * @param achievementId Achievement token ID
     */
    function unlockAchievement(address user, uint256 achievementId) external onlyOwner {
        require(hasProfile[user], "Profile does not exist");
        require(achievementId >= ACHIEVEMENT_START_ID, "Invalid achievement ID");
        require(balanceOf(user, achievementId) == 0, "Achievement already unlocked");

        _mint(user, achievementId, 1, "");
        emit AchievementUnlocked(user, achievementId);
    }

    /**
     * @dev Increments market participation stats
     * @param user User address
     * @param isCreator Whether the user created the market
     */
    function incrementMarketStats(address user, bool isCreator) external onlyOwner {
        require(hasProfile[user], "Profile does not exist");
        
        if (isCreator) {
            profiles[user].marketsCreated++;
        } else {
            profiles[user].marketsParticipated++;
        }
    }

    /**
     * @dev Increments winning predictions count
     * @param user User address
     */
    function incrementWinningPredictions(address user) external onlyOwner {
        require(hasProfile[user], "Profile does not exist");
        profiles[user].winningPredictions++;
    }

    /**
     * @dev Prevent token transfers (soulbound implementation)
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual override {
        require(from == address(0) || to == address(0), "Tokens are soulbound");
        super._update(from, to, ids, amounts);
    }

    /**
     * @dev Returns profile data for a user
     * @param user User address
     */
    function getProfile(address user) external view returns (Profile memory) {
        require(hasProfile[user], "Profile does not exist");
        return profiles[user];
    }

    /**
     * @dev Returns URI for a token ID
     * @param tokenId Token ID
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        if (tokenId == PROFILE_TOKEN) {
            return "";  // Profile token has no URI
        }
        return achievementURIs[tokenId];
    }

    /**
     * @dev Updates social links for a user
     * @param platform Social platform name (e.g., "twitter", "discord")
     * @param link Social profile link
     */
    function updateSocialLink(string memory platform, string memory link) external {
        require(hasProfile[msg.sender], "Profile does not exist");
        socialLinks[msg.sender][platform] = link;
    }

    /**
     * @dev Updates token balance for a user
     * @param user User address
     * @param tokenId Token ID
     * @param newBalance New token balance
     */
    function updateTokenBalance(address user, uint256 tokenId, uint256 newBalance) external onlyOwner {
        require(hasProfile[user], "Profile does not exist");
        
        uint256 oldBalance = tokenBalances[user][tokenId];
        tokenBalances[user][tokenId] = newBalance;
        
        // Add tokenId to tokenIds array if it's a new token
        if (oldBalance == 0 && newBalance > 0) {
            profiles[user].tokenIds.push(tokenId);
        }
        
        emit TokenBalanceUpdated(user, tokenId, newBalance);
    }

    /**
     * @dev Returns token balances for a user
     * @param user User address
     * @return tokenIds Array of token IDs
     * @return balances Array of corresponding balances
     */
    function getUserTokenBalances(address user) external view returns (uint256[] memory tokenIds, uint256[] memory balances) {
        require(hasProfile[user], "Profile does not exist");
        
        uint256[] memory userTokenIds = profiles[user].tokenIds;
        uint256[] memory userBalances = new uint256[](userTokenIds.length);
        
        for (uint256 i = 0; i < userTokenIds.length; i++) {
            userBalances[i] = tokenBalances[user][userTokenIds[i]];
        }
        
        return (userTokenIds, userBalances);
    }

    /**
     * @dev Updates user's online status
     * @param isOnline New online status
     */
    function updateOnlineStatus(bool isOnline) external {
        require(hasProfile[msg.sender], "Profile does not exist");
        
        Profile storage profile = profiles[msg.sender];
        if (profile.isOnline != isOnline) {
            profile.isOnline = isOnline;
            emit OnlineStatusUpdated(msg.sender, isOnline);
        }
        
        profile.lastActive = block.timestamp;
        emit UserActivity(msg.sender, block.timestamp);
    }

    /**
     * @dev Records user activity and updates last active timestamp
     */
    function recordActivity() external {
        require(hasProfile[msg.sender], "Profile does not exist");
        
        Profile storage profile = profiles[msg.sender];
        profile.lastActive = block.timestamp;
        emit UserActivity(msg.sender, block.timestamp);
    }

    /**
     * @dev Checks if a user is currently online
     * @param user Address of the user to check
     * @return bool True if user is online and active within ONLINE_TIMEOUT
     */
    function isUserOnline(address user) external view returns (bool) {
        if (!hasProfile[user]) return false;
        
        Profile storage profile = profiles[user];
        return profile.isOnline && (block.timestamp - profile.lastActive <= ONLINE_TIMEOUT);
    }

    /**
     * @dev Appoint a new moderator
     * @param user Address to appoint as moderator
     * @param canBanUsers Permission to ban users
     * @param canModerateContent Permission to moderate content
     */
    function appointModerator(
        address user,
        bool canBanUsers,
        bool canModerateContent
    ) external onlyRole(ADMIN_ROLE) {
        require(hasProfile[user], "User must have a profile");
        require(!hasRole(MODERATOR_ROLE, user), "Already a moderator");
        
        _grantRole(MODERATOR_ROLE, user);
        
        moderatorData[user] = ModeratorData({
            actionsCount: 0,
            reportsHandled: 0,
            appointedAt: block.timestamp,
            canBanUsers: canBanUsers,
            canModerateContent: canModerateContent
        });

        Profile storage profile = profiles[user];
        profile.profileType = ProfileType.MODERATOR;
        
        emit ModeratorAppointed(user, block.timestamp);
    }

    /**
     * @dev Appoint a new admin
     * @param user Address to appoint as admin
     * @param canGrantRoles Permission to grant roles
     * @param canUpdateContract Permission to update contract
     * @param canPause Permission to pause contract
     */
    function appointAdmin(
        address user,
        bool canGrantRoles,
        bool canUpdateContract,
        bool canPause
    ) external onlyRole(ADMIN_ROLE) {
        require(hasProfile[user], "User must have a profile");
        require(!hasRole(ADMIN_ROLE, user), "Already an admin");
        require(adminData[msg.sender].canGrantRoles, "No permission to grant roles");
        
        _grantRole(ADMIN_ROLE, user);
        
        adminData[user] = AdminData({
            appointedAt: block.timestamp,
            canGrantRoles: canGrantRoles,
            canUpdateContract: canUpdateContract,
            canPause: canPause
        });

        Profile storage profile = profiles[user];
        profile.profileType = ProfileType.ADMIN;
        
        emit AdminAppointed(user, block.timestamp);
    }

    /**
     * @dev Ban a user
     * @param user Address to ban
     */
    function banUser(address user) external onlyRole(MODERATOR_ROLE) {
        require(!bannedUsers[user], "User already banned");
        require(moderatorData[msg.sender].canBanUsers, "No permission to ban users");
        
        bannedUsers[user] = true;
        moderatorData[msg.sender].actionsCount++;
        
        emit UserBanned(user, msg.sender, block.timestamp);
    }

    /**
     * @dev Unban a user
     * @param user Address to unban
     */
    function unbanUser(address user) external onlyRole(MODERATOR_ROLE) {
        require(bannedUsers[user], "User not banned");
        require(moderatorData[msg.sender].canBanUsers, "No permission to ban users");
        
        bannedUsers[user] = false;
        moderatorData[msg.sender].actionsCount++;
        
        emit UserUnbanned(user, msg.sender, block.timestamp);
    }

    /**
     * @dev Record a moderation action
     * @param actionType Type of action taken
     */
    function recordModeratorAction(string memory actionType) external onlyRole(MODERATOR_ROLE) {
        moderatorData[msg.sender].actionsCount++;
        emit ModeratorActionTaken(msg.sender, actionType, block.timestamp);
    }

    /**
     * @dev Required override for AccessControl
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return ERC1155.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }
} 