// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "../interfaces/IAggregatorV3.sol";
import "../interfaces/IContractRegistry.sol";
import "../interfaces/IHydraCurve.sol";
import "../interfaces/ITokenFactory.sol";

contract PriceOracle is Initializable, OwnableUpgradeable, PausableUpgradeable {
    // State variables
    IContractRegistry public registry;
    mapping(address => IAggregatorV3) public priceFeeds;
    mapping(address => uint256) public lastPriceUpdate;
    mapping(address => uint256) public prices;

    // Constants
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant MAX_PRICE_AGE = 1 hours;
    uint256 public constant MAX_PRICE_DEVIATION = 10; // 10% max deviation

    // Events
    event PriceFeedUpdated(address indexed token, address indexed feed);
    event PriceUpdated(address indexed token, uint256 price);
    event PriceDeviation(address indexed token, uint256 oldPrice, uint256 newPrice);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _registry,
        address[] memory tokens,
        address[] memory feeds
    ) external initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();

        require(_registry != address(0), "Invalid registry");
        require(tokens.length == feeds.length, "Length mismatch");

        registry = IContractRegistry(_registry);

        // Initialize price feeds
        for (uint i = 0; i < tokens.length; i++) {
            _setPriceFeed(tokens[i], feeds[i]);
        }
    }

    // External functions
    function getPrice(address token) external view returns (uint256) {
        if (_isStablecoin(token)) {
            return PRICE_PRECISION; // $1.00
        }

        if (_isD4LToken(token)) {
            return _getD4LTokenPrice(token);
        }

        return _getPriceFeedPrice(token);
    }

    function updatePrice(address token) external whenNotPaused returns (uint256) {
        uint256 price;
        
        if (_isStablecoin(token)) {
            price = PRICE_PRECISION;
        } else if (_isD4LToken(token)) {
            price = _getD4LTokenPrice(token);
        } else {
            price = _getPriceFeedPrice(token);
        }

        // Check for significant price deviations
        uint256 oldPrice = prices[token];
        if (oldPrice > 0) {
            uint256 deviation = _calculateDeviation(oldPrice, price);
            if (deviation > MAX_PRICE_DEVIATION) {
                emit PriceDeviation(token, oldPrice, price);
                _pause(); // Pause oracle if large deviation detected
                return oldPrice;
            }
        }

        prices[token] = price;
        lastPriceUpdate[token] = block.timestamp;
        emit PriceUpdated(token, price);

        return price;
    }

    // Admin functions
    function setPriceFeed(address token, address feed) external onlyOwner {
        _setPriceFeed(token, feed);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Internal functions
    function _setPriceFeed(address token, address feed) internal {
        require(token != address(0), "Invalid token");
        require(feed != address(0), "Invalid feed");
        priceFeeds[token] = IAggregatorV3(feed);
        emit PriceFeedUpdated(token, feed);
    }

    function _isStablecoin(address token) internal pure returns (bool) {
        return token == 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb || // USDT
               token == 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;   // USDC
    }

    function _isD4LToken(address token) internal view returns (bool) {
        address factory = registry.getContractAddressByName("TOKEN_FACTORY");
        return ITokenFactory(factory).isD4LToken(token);
    }

    function _getD4LTokenPrice(address token) internal view returns (uint256) {
        address curve = registry.getContractAddressByName("HYDRA_CURVE");
        return IHydraCurve(curve).calculatePrice(token, PRICE_PRECISION);
    }

    function _getPriceFeedPrice(address token) internal view returns (uint256) {
        IAggregatorV3 feed = priceFeeds[token];
        require(address(feed) != address(0), "No price feed");

        (, int256 price,, uint256 updatedAt,) = feed.latestRoundData();
        require(price > 0, "Invalid price");
        require(block.timestamp - updatedAt <= MAX_PRICE_AGE, "Stale price");

        return uint256(price) * PRICE_PRECISION / (10 ** feed.decimals());
    }

    function _calculateDeviation(uint256 oldPrice, uint256 newPrice) internal pure returns (uint256) {
        if (oldPrice > newPrice) {
            return ((oldPrice - newPrice) * 100) / oldPrice;
        }
        return ((newPrice - oldPrice) * 100) / oldPrice;
    }
} 