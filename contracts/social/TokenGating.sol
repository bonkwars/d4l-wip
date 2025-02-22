// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenGating {
    // Pack related storage variables together
    struct GateConfig {
        address token;          // 20 bytes
        uint96 minAmount;       // 12 bytes (reduced from uint256)
        uint32 tokenId;        // 4 bytes (reduced from uint256)
        uint8 gateType;        // 1 byte (enum as uint8)
        bool active;           // 1 byte
        uint8 reserved;        // 1 byte padding
    }

    // Cache storage reads
    struct GateStatus {
        bool exists;
        bool isActive;
        uint256 usageCount;
    }

    // Events - indexed for efficient filtering
    event GateConfigured(bytes32 indexed id, address indexed token, uint96 minAmount);
    event GateRemoved(bytes32 indexed id);
    event OverrideSet(bytes32 indexed id, address indexed user, bool status);
    event GateUsed(bytes32 indexed gateId, address indexed user, uint256 timestamp);

    // Custom errors save gas over require strings
    error Unauthorized();
    error InvalidConfig();
    error GateNotFound();
    error TokenCallFailed();

    // Constants
    uint256 private constant MAX_UINT96 = type(uint96).max;
    bytes32 private constant MANAGER_ROLE = keccak256("GATE_MANAGER_ROLE");
    
    // Mappings
    mapping(bytes32 => GateConfig) private _gates;
    mapping(bytes32 => mapping(address => bool)) private _overrides;
    mapping(bytes32 => bool) private _activeGates;
    mapping(bytes32 => uint256) private _gateUsageCount;
    mapping(address => bool) private _gateManagers;

    modifier onlyManager() {
        if (!_gateManagers[msg.sender]) revert Unauthorized();
        _;
    }

    function configureGate(
        bytes32 id,
        address token,
        uint96 minAmount,
        uint32 tokenId,
        uint8 gateType
    ) external onlyManager {
        // Validate inputs
        if (token == address(0) || minAmount == 0 || gateType > 2) {
            revert InvalidConfig();
        }

        // Use assembly for efficient storage packing
        assembly {
            // Pack gate config into a single storage slot
            let config := mload(0x40)
            mstore(config, token)                  // token address (20 bytes)
            mstore(add(config, 20), minAmount)     // minAmount (12 bytes)
            mstore(add(config, 32), tokenId)       // tokenId (4 bytes)
            mstore8(add(config, 36), gateType)     // gateType (1 byte)
            mstore8(add(config, 37), 1)            // active (1 byte)
            
            // Store packed config
            sstore(keccak256(id, 32), mload(config))
        }

        _activeGates[id] = true;
        emit GateConfigured(id, token, minAmount);
    }

    function checkAccess(bytes32 id, address user) public returns (bool) {
        // Cache storage reads
        GateConfig storage gate = _gates[id];
        if (!gate.active) revert GateNotFound();

        bool hasAccess;
        if (_overrides[id][user]) {
            hasAccess = true;
        } else {
            // Use try-catch for external calls
            try this._checkTokenBalance(gate.token, user, gate.minAmount, gate.gateType) returns (bool result) {
                hasAccess = result;
            } catch {
                revert TokenCallFailed();
            }
        }

        if (hasAccess) {
            unchecked {
                // Gas optimization for counter increment
                _gateUsageCount[id]++;
            }
            emit GateUsed(id, user, block.timestamp);
        }

        return hasAccess;
    }

    // External function for try-catch
    function _checkTokenBalance(
        address token,
        address user,
        uint96 minAmount,
        uint8 gateType
    ) external view returns (bool) {
        if (gateType == 0) {
            return IERC20(token).balanceOf(user) >= minAmount;
        } else if (gateType == 1) {
            return IERC721(token).balanceOf(user) >= minAmount;
        } else {
            return IERC1155(token).balanceOf(user, uint256(minAmount)) > 0;
        }
    }
} 