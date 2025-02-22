// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ILaunchpad.sol";
import "solmate/src/auth/Owned.sol";

/// @title LaunchpadAPI
/// @notice Centralized API for interacting with the Launchpad protocol
/// @dev Provides simplified interfaces and batched operations
contract LaunchpadAPI is Owned {
    ILaunchpad public immutable launchpad;
    
    // Events for tracking API usage
    event LaunchCreated(address indexed token, address indexed creator, uint96 price);
    event BatchParticipation(address indexed token, address[] participants, uint96[] amounts);
    event BatchPumpAction(address indexed token, address[] pumpers, uint96[] amounts);
    event BatchSocialAction(address indexed token, address[] users, string[] actionTypes);
    
    constructor(address _launchpad) Owned(msg.sender) {
        launchpad = ILaunchpad(_launchpad);
    }
    
    /// @notice Creates a new token launch with simplified parameters
    function createLaunch(
        address token,
        uint96 price,
        uint96 softCap,
        uint96 hardCap,
        uint32 duration,
        uint16 pumpRewardBps,
        bool whitelistEnabled,
        string calldata metadataCid
    ) external payable returns (bool) {
        ILaunchpad.LaunchConfig memory config = ILaunchpad.LaunchConfig({
            initialPrice: price,
            softCap: softCap,
            hardCap: hardCap,
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + duration),
            pumpRewardBps: pumpRewardBps,
            status: 1,
            whitelistEnabled: whitelistEnabled
        });
        
        launchpad.createLaunch{value: msg.value}(token, config, metadataCid);
        emit LaunchCreated(token, msg.sender, price);
        return true;
    }
    
    /// @notice Batch participation for multiple users
    function batchParticipate(
        address token,
        address[] calldata participants,
        uint96[] calldata amounts
    ) external payable returns (bool) {
        require(participants.length == amounts.length, "Length mismatch");
        uint256 totalAmount;
        
        for(uint i = 0; i < participants.length; i++) {
            launchpad.participate{value: amounts[i]}(token, amounts[i]);
            totalAmount += amounts[i];
        }
        
        require(totalAmount == msg.value, "Invalid total value");
        emit BatchParticipation(token, participants, amounts);
        return true;
    }
    
    /// @notice Batch pump action for multiple users
    function batchPump(
        address token,
        address[] calldata pumpers,
        uint96[] calldata amounts
    ) external payable returns (bool) {
        require(pumpers.length == amounts.length, "Length mismatch");
        uint256 totalAmount;
        
        for(uint i = 0; i < pumpers.length; i++) {
            launchpad.pump{value: amounts[i]}(token, amounts[i]);
            totalAmount += amounts[i];
        }
        
        require(totalAmount == msg.value, "Invalid total value");
        emit BatchPumpAction(token, pumpers, amounts);
        return true;
    }
    
    /// @notice Batch social actions for multiple users
    function batchSocialAction(
        address token,
        address[] calldata users,
        string[] calldata actionTypes,
        bytes[] calldata proofs
    ) external returns (bool) {
        require(users.length == actionTypes.length, "Length mismatch");
        require(users.length == proofs.length, "Length mismatch");
        
        for(uint i = 0; i < users.length; i++) {
            launchpad.recordSocialAction(token, actionTypes[i], proofs[i]);
        }
        
        emit BatchSocialAction(token, users, actionTypes);
        return true;
    }
    
    /// @notice Gets complete launch metrics
    function getLaunchMetrics(
        address token
    ) external view returns (
        ILaunchpad.LaunchConfig memory config,
        ILaunchpad.PumpMetrics memory pump,
        ILaunchpad.SocialMetrics memory social
    ) {
        config = launchpad.getLaunchInfo(token);
        pump = launchpad.getPumpMetrics(token);
        social = launchpad.getSocialMetrics(token);
    }
    
    /// @notice Gets user participation data
    function getUserParticipation(
        address token,
        address user
    ) external view returns (
        uint32 rank,
        uint96 score,
        uint96 rewards,
        bool hasParticipated,
        bool hasClaimed
    ) {
        (rank, score, rewards) = launchpad.getUserStats(token, user);
        // Note: hasParticipated and hasClaimed would need to be implemented in the main contract
    }
    
    receive() external payable {}
} 