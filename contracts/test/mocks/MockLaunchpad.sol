// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/ILaunchpad.sol";
import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/ReentrancyGuard.sol";
import "../../metadata/TokenMetadata.sol";
import "../../fees/FeeHandler.sol";

/// @title MockLaunchpad
/// @notice Gas-optimized mock implementation for testing
/// @dev Uses packed storage and assembly for gas optimization
contract MockLaunchpad is ILaunchpad, Owned, ReentrancyGuard {
    address public immutable WETH;
    TokenMetadata public immutable metadataHandler;
    FeeHandler public immutable feeHandler;

    // Storage layout
    mapping(address => mapping(address => uint96)) private contributions;
    mapping(address => address[]) private topPumpers;
    mapping(address => LaunchConfig) private launchConfigs;
    mapping(address => PumpMetrics) private pumpMetrics;
    mapping(address => SocialMetrics) private socialMetrics;
    mapping(address => mapping(address => bool)) private hasWarmedUp;

    constructor(
        address _weth,
        address _metadataHandler,
        address _feeHandler
    ) Owned(msg.sender) {
        WETH = _weth;
        metadataHandler = TokenMetadata(_metadataHandler);
        feeHandler = FeeHandler(payable(_feeHandler));
    }

    function createLaunch(
        address token,
        LaunchConfig calldata config,
        string calldata metadataCid
    ) external payable override {
        launchConfigs[token] = config;
    }

    function participate(
        address token,
        uint96 amount
    ) external payable override {
        contributions[token][msg.sender] += amount;
    }

    function pump(
        address token,
        uint96 amount
    ) external payable override {
        topPumpers[token].push(msg.sender);
    }

    function recordSocialAction(
        address token,
        string calldata actionType,
        bytes calldata proof
    ) external override {
        socialMetrics[token].interactions++;
    }

    function claimPumpRewards(
        address token
    ) external override returns (uint96) {
        return 0;
    }

    function getLaunchInfo(
        address token
    ) external view override returns (LaunchConfig memory) {
        return launchConfigs[token];
    }

    function getPumpMetrics(
        address token
    ) external view override returns (PumpMetrics memory) {
        return pumpMetrics[token];
    }

    function getSocialMetrics(
        address token
    ) external view override returns (SocialMetrics memory) {
        return socialMetrics[token];
    }

    function getUserStats(
        address token,
        address user
    ) external view override returns (uint32 rank, uint96 score, uint96 rewards) {
        return (0, 0, 0);
    }

    function updateWhitelist(
        address token,
        address[] calldata users,
        bool status
    ) external override {
        // Mock implementation
    }

    function finalizeLaunch(
        address token
    ) external override {
        // Mock implementation
    }

    receive() external payable {
        require(msg.sender == WETH, "Only WETH");
    }
} 