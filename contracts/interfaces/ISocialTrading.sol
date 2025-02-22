// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISocialTrading {
    struct Trader {
        uint256 reputation;
        uint256 successfulTrades;
        uint256 totalTrades;
        uint256 totalVolume;
        uint256 followers;
        bool isActive;
        string profileURI;
    }

    struct Strategy {
        address trader;
        string name;
        string description;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 performanceFee;
        bool isActive;
    }

    struct CopyTrading {
        address follower;
        address trader;
        uint256 amount;
        uint256 startTime;
        uint256 lastCopyTime;
        bool isActive;
    }

    event TraderRegistered(address indexed trader, string profileURI);
    event StrategyCreated(bytes32 indexed strategyId, address indexed trader, string name);
    event CopyTradeStarted(address indexed follower, address indexed trader, uint256 amount);
    event CopyTradeStopped(address indexed follower, address indexed trader);
    event TradeExecuted(address indexed trader, address indexed follower, bytes32 indexed tradeId);
    event ReputationUpdated(address indexed trader, uint256 newReputation);

    /**
     * @notice Registers a new trader
     * @param profileURI IPFS URI of trader profile
     */
    function registerTrader(string calldata profileURI) external;

    /**
     * @notice Creates a new trading strategy
     * @param name Strategy name
     * @param description Strategy description
     * @param minAmount Minimum copy amount
     * @param maxAmount Maximum copy amount
     * @param performanceFee Performance fee in basis points
     * @return strategyId The ID of the created strategy
     */
    function createStrategy(
        string calldata name,
        string calldata description,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 performanceFee
    ) external returns (bytes32);

    /**
     * @notice Starts copy trading a trader
     * @param trader Address of trader to copy
     * @param amount Amount to allocate for copy trading
     */
    function startCopyTrading(address trader, uint256 amount) external;

    /**
     * @notice Stops copy trading a trader
     * @param trader Address of trader to stop copying
     */
    function stopCopyTrading(address trader) external;

    /**
     * @notice Records a successful trade and updates reputation
     * @param trader Address of trader
     * @param volume Trade volume
     * @param success Whether trade was successful
     */
    function recordTrade(address trader, uint256 volume, bool success) external;

    /**
     * @notice Gets all traders being followed by a user
     * @param user Address of user
     * @return traders Array of trader addresses
     */
    function getFollowing(address user) external view returns (address[] memory);

    /**
     * @notice Gets all followers of a trader
     * @param trader Address of trader
     * @return followers Array of follower addresses
     */
    function getFollowers(address trader) external view returns (address[] memory);

    /**
     * @notice Gets trader details
     * @param trader Address of trader
     * @return traderData The trader details
     */
    function getTrader(address trader) external view returns (Trader memory);

    /**
     * @notice Gets copy trading details
     * @param follower Address of follower
     * @param trader Address of trader
     * @return copyTrading The copy trading details
     */
    function getCopyTrading(
        address follower,
        address trader
    ) external view returns (CopyTrading memory);

    /**
     * @notice Gets strategy details
     * @param strategyId Strategy ID
     * @return strategy The strategy details
     */
    function strategies(bytes32 strategyId) external view returns (Strategy memory);

    /**
     * @notice Gets trader details
     * @param trader Address of trader
     * @return trader_ The trader details
     */
    function traders(address trader) external view returns (Trader memory);
} 