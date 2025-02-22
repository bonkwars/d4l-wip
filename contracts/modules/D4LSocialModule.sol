// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SocialModule.sol";

contract D4LSocialModule is SocialModule {
    mapping(bytes32 => Gate) internal _gates;

    struct Gate {
        uint256 gateId;
        address token;
        uint256 threshold;
        bool active;
    }

    function initialize(address _registry) external override initializer {
        __BaseModule_init(_registry);
    }

    function createTokenGate(
        address token,
        uint256 minHoldAmount,
        uint256 minHoldDuration,
        uint256 requiredLevel,
        bool requireVerification,
        bool enableTrading,
        bool enableStaking
    ) public override {
        bytes32 gateId = keccak256(abi.encodePacked(token, minHoldAmount, minHoldDuration));
        
        // Directly assign to storage without intermediate memory variable
        _gates[gateId] = Gate({
            gateId: uint256(gateId),
            token: token,
            threshold: minHoldAmount,
            active: true
        });
        
        emit TokenGateCreated(gateId, token, uint96(minHoldAmount));
    }

    function createGate(bytes32 gateId, address token, uint256 threshold) external {
        require(_gates[gateId].gateId == 0, "Gate already exists");
        
        _gates[gateId] = Gate({
            gateId: uint256(gateId),
            token: token,
            threshold: threshold,
            active: true
        });
    }
} 