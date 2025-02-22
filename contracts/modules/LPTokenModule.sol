// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "../interfaces/IContractRegistry.sol";
import "../interfaces/ILPToken.sol";

/**
 * @title LPTokenModule
 * @notice NFT representation of liquidity positions with additional features
 */
contract LPTokenModule is 
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    // State variables
    IContractRegistry public registry;
    
    struct LiquidityPosition {
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
        uint256 liquidity;
        uint256 startTime;
        uint256 lastHarvestTime;
        uint256 accumulatedFees;
        bool isStaked;
    }

    // Mappings
    mapping(uint256 => LiquidityPosition) public positions;
    mapping(address => mapping(address => uint256[])) public userPositions; // user => (tokenA => positionIds)
    mapping(uint256 => uint256) public positionScore; // positionId => governance score
    mapping(uint256 => string) private _tokenURIs;
    
    // Counter for token IDs
    uint256 private _tokenIdCounter;

    // Events
    event PositionCreated(uint256 indexed tokenId, address indexed owner, address tokenA, address tokenB, uint256 amountA, uint256 amountB);
    event PositionModified(uint256 indexed tokenId, uint256 newAmountA, uint256 newAmountB);
    event PositionClosed(uint256 indexed tokenId);
    event FeesHarvested(uint256 indexed tokenId, uint256 amount);
    event PositionStaked(uint256 indexed tokenId);
    event PositionUnstaked(uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _registry
    ) external initializer {
        __ERC721_init("D4L Liquidity Position", "D4L-LP");
        __ERC721Enumerable_init();
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_registry != address(0), "Invalid registry");
        registry = IContractRegistry(_registry);
    }

    /**
     * @notice Creates a new liquidity position NFT
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param amountA Amount of first token
     * @param amountB Amount of second token
     * @return tokenId The ID of the created position NFT
     */
    function createPosition(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(tokenA != address(0) && tokenB != address(0), "Invalid tokens");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        uint256 tokenId = _tokenIdCounter++;
        
        LiquidityPosition memory position = LiquidityPosition({
            tokenA: tokenA,
            tokenB: tokenB,
            amountA: amountA,
            amountB: amountB,
            liquidity: _calculateLiquidity(amountA, amountB),
            startTime: block.timestamp,
            lastHarvestTime: block.timestamp,
            accumulatedFees: 0,
            isStaked: false
        });

        positions[tokenId] = position;
        userPositions[msg.sender][tokenA].push(tokenId);
        
        _safeMint(msg.sender, tokenId);
        
        emit PositionCreated(tokenId, msg.sender, tokenA, tokenB, amountA, amountB);
        
        return tokenId;
    }

    /**
     * @notice Modifies an existing liquidity position
     * @param tokenId The ID of the position to modify
     * @param newAmountA New amount of first token
     * @param newAmountB New amount of second token
     */
    function modifyPosition(
        uint256 tokenId,
        uint256 newAmountA,
        uint256 newAmountB
    ) external nonReentrant whenNotPaused {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not authorized");
        require(newAmountA > 0 && newAmountB > 0, "Invalid amounts");

        LiquidityPosition storage position = positions[tokenId];
        require(!position.isStaked, "Position is staked");

        position.amountA = newAmountA;
        position.amountB = newAmountB;
        position.liquidity = _calculateLiquidity(newAmountA, newAmountB);

        emit PositionModified(tokenId, newAmountA, newAmountB);
    }

    /**
     * @notice Stakes a liquidity position for governance rights
     * @param tokenId The ID of the position to stake
     */
    function stakePosition(uint256 tokenId) external nonReentrant whenNotPaused {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not authorized");
        
        LiquidityPosition storage position = positions[tokenId];
        require(!position.isStaked, "Already staked");

        position.isStaked = true;
        positionScore[tokenId] = _calculateGovernanceScore(position);

        emit PositionStaked(tokenId);
    }

    /**
     * @notice Unstakes a liquidity position
     * @param tokenId The ID of the position to unstake
     */
    function unstakePosition(uint256 tokenId) external nonReentrant {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not authorized");
        
        LiquidityPosition storage position = positions[tokenId];
        require(position.isStaked, "Not staked");

        position.isStaked = false;
        positionScore[tokenId] = 0;

        emit PositionUnstaked(tokenId);
    }

    /**
     * @notice Harvests accumulated fees for a position
     * @param tokenId The ID of the position
     * @return amount The amount of fees harvested
     */
    function harvestFees(uint256 tokenId) external nonReentrant returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not authorized");
        
        LiquidityPosition storage position = positions[tokenId];
        uint256 newFees = _calculateAccumulatedFees(position);
        
        if (newFees > 0) {
            position.accumulatedFees += newFees;
            position.lastHarvestTime = block.timestamp;
            
            emit FeesHarvested(tokenId, newFees);
        }
        
        return newFees;
    }

    /**
     * @notice Gets all positions for a user and token
     * @param user Address of the user
     * @param token Address of the token
     * @return positionIds Array of position IDs
     */
    function getUserPositions(address user, address token) external view returns (uint256[] memory) {
        return userPositions[user][token];
    }

    /**
     * @notice Gets the governance score for a position
     * @param tokenId The ID of the position
     * @return score The governance score
     */
    function getGovernanceScore(uint256 tokenId) external view returns (uint256) {
        return positionScore[tokenId];
    }

    /**
     * @dev Sets the token URI for a given token ID
     * @param tokenId The token ID to set the URI for
     * @param _tokenURI The URI to set
     */
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
        require(_ownerOf(tokenId) != address(0), "URI set of nonexistent token");
        require(ownerOf(tokenId) == msg.sender, "Not authorized");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev Gets the token URI for a given token ID
     * @param tokenId The token ID to get the URI for
     * @return The token's URI
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    // Internal functions
    function _calculateLiquidity(uint256 amountA, uint256 amountB) internal pure returns (uint256) {
        return sqrt(amountA * amountB);
    }

    function _calculateGovernanceScore(LiquidityPosition memory position) internal view returns (uint256) {
        uint256 timeWeight = (block.timestamp - position.startTime) / 1 days;
        return (position.liquidity * timeWeight) / 100;
    }

    function _calculateAccumulatedFees(LiquidityPosition memory position) internal view returns (uint256) {
        uint256 timePassed = block.timestamp - position.lastHarvestTime;
        return (position.liquidity * timePassed * 3) / (365 days * 1000); // 0.3% annual fee rate
    }

    /**
     * @notice Closes a liquidity position
     * @param tokenId The ID of the position to close
     */
    function closePosition(uint256 tokenId) external nonReentrant whenNotPaused {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not authorized");
        
        LiquidityPosition storage position = positions[tokenId];
        require(!position.isStaked, "Position is staked");

        // Close position by setting amounts to 0
        position.amountA = 0;
        position.amountB = 0;
        position.liquidity = 0;

        emit PositionClosed(tokenId);
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
} 