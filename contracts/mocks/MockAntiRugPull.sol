// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IAntiRugPull.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MockAntiRugPull is IAntiRugPull, Initializable {
    address public token;
    address public registry;
    mapping(address => mapping(address => bool)) public whitelisted;
    mapping(address => LockConfig) public lockConfigs;
    bool private _ownershipRenounced;
    uint256 private _lockedAmount;
    uint256 private _unlockTime;

    function initialize(address _token, address _registry) external initializer {
        token = _token;
        registry = _registry;
    }

    function setWhitelisted(
        address _token,
        address account,
        bool status
    ) external override {
        require(_token == token, "Invalid token");
        whitelisted[_token][account] = status;
    }

    function updateLockConfig(LockConfig calldata config) external override {
        lockConfigs[msg.sender] = config;
    }

    function canSell(
        address seller,
        uint256 amount
    ) external view override returns (bool, string memory) {
        return (true, ""); // Mock implementation always allows selling
    }

    function lockLiquidity(uint256 amount, uint256 duration) external override {
        _lockedAmount = amount;
        _unlockTime = block.timestamp + duration;
    }

    function renounceOwnership() external override {
        _ownershipRenounced = true;
    }

    function getLockConfig() external view override returns (LockConfig memory) {
        return lockConfigs[msg.sender];
    }

    function getLockedLiquidity() external view override returns (uint256 amount, uint256 unlockTime) {
        return (_lockedAmount, _unlockTime);
    }

    function isOwnershipRenounced() external view override returns (bool) {
        return _ownershipRenounced;
    }

    function getMaxSellAmount() external view override returns (uint256) {
        return type(uint256).max; // Mock implementation returns max uint256
    }

    function checkSellLimit(address _token, uint256 amount) external override returns (bool) {
        require(_token == token, "Invalid token");
        return true; // Mock implementation always returns true
    }
} 