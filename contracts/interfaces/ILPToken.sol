// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILPToken {
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

    event PositionCreated(uint256 indexed tokenId, address indexed owner, address tokenA, address tokenB, uint256 amountA, uint256 amountB);
    event PositionModified(uint256 indexed tokenId, uint256 newAmountA, uint256 newAmountB);
    event PositionClosed(uint256 indexed tokenId);
    event FeesHarvested(uint256 indexed tokenId, uint256 amount);
    event PositionStaked(uint256 indexed tokenId);
    event PositionUnstaked(uint256 indexed tokenId);

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
    ) external returns (uint256);

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
    ) external;

    /**
     * @notice Stakes a liquidity position for governance rights
     * @param tokenId The ID of the position to stake
     */
    function stakePosition(uint256 tokenId) external;

    /**
     * @notice Unstakes a liquidity position
     * @param tokenId The ID of the position to unstake
     */
    function unstakePosition(uint256 tokenId) external;

    /**
     * @notice Harvests accumulated fees for a position
     * @param tokenId The ID of the position
     * @return amount The amount of fees harvested
     */
    function harvestFees(uint256 tokenId) external returns (uint256);

    /**
     * @notice Gets all positions for a user and token
     * @param user Address of the user
     * @param token Address of the token
     * @return positionIds Array of position IDs
     */
    function getUserPositions(address user, address token) external view returns (uint256[] memory);

    /**
     * @notice Gets the governance score for a position
     * @param tokenId The ID of the position
     * @return score The governance score
     */
    function getGovernanceScore(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Gets details of a liquidity position
     * @param tokenId The ID of the position
     * @return position The position details
     */
    function positions(uint256 tokenId) external view returns (LiquidityPosition memory);
} 