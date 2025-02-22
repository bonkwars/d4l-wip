// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICrossChainBridge.sol";

abstract contract AbstractCrossChainBridge is Ownable, ReentrancyGuard, ICrossChainBridge {
    // Packed storage for bridge configuration (single slot)
    struct PackedBridgeConfig {
        uint32 minAmount;      // 4 bytes
        uint32 maxAmount;      // 4 bytes
        uint32 bridgeFee;      // 4 bytes
        bool paused;           // 1 byte
        uint8 reserved;        // 3 bytes padding
    }

    // Mapping: keccak256(sourceChainId, targetChainId) => PackedBridgeConfig
    mapping(bytes32 => PackedBridgeConfig) private _bridgeConfigs;
    
    // Mapping: keccak256(sourceChainId, targetChainId) => (sourceToken, targetToken)
    mapping(bytes32 => address[2]) private _bridgeTokens;
    
    // Mapping: nonce => BridgeRequest
    mapping(uint256 => BridgeRequest) private _bridgeRequests;
    
    // Nonce counter for bridge requests
    uint256 private _nonce;
    
    // Validator address for signature verification
    address public immutable validator;
    
    // EIP-712 domain separator
    bytes32 private immutable _DOMAIN_SEPARATOR;

    // Add nonce tracking per chain
    mapping(uint256 => mapping(bytes32 => bool)) private _usedNonces;

    // Add chain validation
    mapping(uint256 => bool) private _supportedChains;
    
    // Add active config tracking
    mapping(bytes32 => bool) private _activeConfigs;
    bytes32[] private _activeConfigList;

    event ChainSupported(uint256 chainId);
    event ChainRemoved(uint256 chainId);

    // Add recovery functionality
    event TokensRecovered(address indexed token, address indexed recipient, uint256 amount);
    event NativeTokenRecovered(address indexed recipient, uint256 amount);

    
    constructor(address _validator) Ownable(msg.sender) {
        validator = _validator;
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Degen4Life Bridge"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice Initiates a bridge transfer to another chain
    function initiateBridge(
        uint256 targetChainId,
        address recipient,
        uint256 amount
    ) external payable override nonReentrant returns (uint256 nonce) {
        require(_supportedChains[targetChainId], "Unsupported chain");
        bytes32 configKey = _getConfigKey(block.chainid, targetChainId);
        PackedBridgeConfig memory config = _bridgeConfigs[configKey];
        require(!config.paused, "Bridge is paused");
        require(amount >= config.minAmount && amount <= config.maxAmount, "Invalid amount");

        address sourceToken = _bridgeTokens[configKey][0];
        require(sourceToken != address(0), "Bridge not configured");

        // Transfer tokens to bridge
        require(
            IERC20(sourceToken).transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        // Create bridge request
        nonce = ++_nonce;
        _bridgeRequests[nonce] = BridgeRequest({
            nonce: nonce,
            sender: msg.sender,
            recipient: recipient,
            amount: amount,
            timestamp: uint32(block.timestamp), // Gas optimization: uint32 is sufficient
            executed: false
        });

        emit BridgeInitiated(
            block.chainid,
            targetChainId,
            msg.sender,
            recipient,
            amount,
            nonce
        );
        return nonce;
    }

    /// @notice Completes a bridge transfer on the target chain
    function completeBridge(
        uint256 sourceChainId,
        address sender,
        address recipient,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) external override nonReentrant {
        require(_supportedChains[sourceChainId], "Unsupported chain");
        bytes32 nonceHash = keccak256(abi.encodePacked(sourceChainId, block.chainid, nonce));
        require(!_usedNonces[sourceChainId][nonceHash], "Nonce already used");
        _usedNonces[sourceChainId][nonceHash] = true;
        
        bytes32 configKey = _getConfigKey(sourceChainId, block.chainid);
        PackedBridgeConfig memory config = _bridgeConfigs[configKey];
        require(!config.paused, "Bridge is paused");

        require(
            validateSignature(sourceChainId, sender, recipient, amount, nonce, signature),
            "Invalid signature"
        );

        BridgeRequest storage request = _bridgeRequests[nonce];
        require(!request.executed, "Already executed");
        request.executed = true;

        address targetToken = _bridgeTokens[configKey][1];
        require(targetToken != address(0), "Bridge not configured");

        // Transfer tokens to recipient
        require(
            IERC20(targetToken).transfer(recipient, amount),
            "Transfer failed"
        );

        emit BridgeCompleted(
            sourceChainId,
            block.chainid,
            recipient,
            amount,
            nonce
        );
    }

    /// @notice Updates the bridge configuration
    function updateBridgeConfig(
        uint256 sourceChainId,
        uint256 targetChainId,
        BridgeConfig calldata config
    ) external override onlyOwner {
        bytes32 configKey = _getConfigKey(sourceChainId, targetChainId);
        
        // Track active config
        if (!_activeConfigs[configKey]) {
            _activeConfigs[configKey] = true;
            _activeConfigList.push(configKey);
        }

        _bridgeConfigs[configKey] = PackedBridgeConfig({
            minAmount: uint32(config.minAmount),
            maxAmount: uint32(config.maxAmount),
            bridgeFee: uint32(config.bridgeFee),
            paused: config.paused,
            reserved: 0
        });

        _bridgeTokens[configKey][0] = config.sourceToken;
        _bridgeTokens[configKey][1] = config.targetToken;

        emit BridgeConfigUpdated(
            sourceChainId,
            targetChainId,
            config.sourceToken,
            config.targetToken,
            config.minAmount,
            config.maxAmount,
            config.bridgeFee
        );
    }

    /// @notice Pauses bridging between two chains
    function pauseBridge(uint256 sourceChainId, uint256 targetChainId) external override onlyOwner {
        bytes32 configKey = _getConfigKey(sourceChainId, targetChainId);
        _bridgeConfigs[configKey].paused = true;
        emit BridgePaused(sourceChainId, targetChainId);
    }

    /// @notice Unpauses bridging between two chains
    function unpauseBridge(uint256 sourceChainId, uint256 targetChainId) external override onlyOwner {
        bytes32 configKey = _getConfigKey(sourceChainId, targetChainId);
        _bridgeConfigs[configKey].paused = false;
        emit BridgeUnpaused(sourceChainId, targetChainId);
    }

    /// @notice Gets the bridge configuration for a chain pair
    function getBridgeConfig(uint256 sourceChainId, uint256 targetChainId)
        external
        view
        override
        returns (BridgeConfig memory)
    {
        bytes32 configKey = _getConfigKey(sourceChainId, targetChainId);
        PackedBridgeConfig memory packed = _bridgeConfigs[configKey];
        address[2] memory tokens = _bridgeTokens[configKey];

        return BridgeConfig({
            sourceChainId: sourceChainId,
            targetChainId: targetChainId,
            sourceToken: tokens[0],
            targetToken: tokens[1],
            minAmount: packed.minAmount,
            maxAmount: packed.maxAmount,
            bridgeFee: packed.bridgeFee,
            paused: packed.paused
        });
    }

    /// @notice Gets a bridge request by nonce
    function getBridgeRequest(uint256 nonce)
        external
        view
        override
        returns (BridgeRequest memory)
    {
        return _bridgeRequests[nonce];
    }

    /// @notice Validates a bridge signature
    function validateSignature(
        uint256 sourceChainId,
        address sender,
        address recipient,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) public view override returns (bool) {
        // Remove state-changing check for view function
        bytes32 nonceHash = keccak256(abi.encodePacked(sourceChainId, block.chainid, nonce));
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Bridge(uint256 sourceChainId,uint256 targetChainId,address sender,address recipient,uint256 amount,uint256 nonce)"),
                sourceChainId,
                block.chainid,
                sender,
                recipient,
                amount,
                nonce
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR, structHash)
        );

        address signer = _recoverSigner(hash, signature);
        return signer == validator;
    }

    /// @notice Calculates the bridge fee for a given amount
    function calculateBridgeFee(
        uint256 sourceChainId,
        uint256 targetChainId,
        uint256 amount
    ) external view override returns (uint256) {
        bytes32 configKey = _getConfigKey(sourceChainId, targetChainId);
        PackedBridgeConfig memory config = _bridgeConfigs[configKey];
        return (amount * config.bridgeFee) / 10000; // Fee in basis points
    }

    // Internal functions
    function _getConfigKey(uint256 sourceChainId, uint256 targetChainId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(sourceChainId, targetChainId));
    }

    function _recoverSigner(bytes32 hash, bytes calldata signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        if (v < 27) v += 27;
        require(v == 27 || v == 28, "Invalid signature v value");

        return ecrecover(hash, v, r, s);
    }

    function addSupportedChain(uint256 chainId) external onlyOwner {
        _supportedChains[chainId] = true;
        emit ChainSupported(chainId);
    }

    function removeSupportedChain(uint256 chainId) external onlyOwner {
        _supportedChains[chainId] = false;
        emit ChainRemoved(chainId);
    }

    function recoverTokens(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");

        // Check if token is part of any active bridge
        bytes32[] memory activeConfigs = getActiveConfigs();
        for (uint256 i = 0; i < activeConfigs.length; i++) {
            address[2] memory tokens = _bridgeTokens[activeConfigs[i]];
            require(token != tokens[0] && token != tokens[1], "Cannot recover bridge token");
        }

        require(
            IERC20(token).transfer(recipient, amount),
            "Transfer failed"
        );

        emit TokensRecovered(token, recipient, amount);
    }

    function recoverNativeToken(address payable recipient, uint256 amount) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0 && amount <= address(this).balance, "Invalid amount");
        
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");

        emit NativeTokenRecovered(recipient, amount);
    }

    function getActiveConfigs() public view returns (bytes32[] memory) {
        return _activeConfigList;
    }

    // Add config removal functionality
    function removeActiveConfig(uint256 sourceChainId, uint256 targetChainId) external onlyOwner {
        bytes32 configKey = _getConfigKey(sourceChainId, targetChainId);
        require(_activeConfigs[configKey], "Config not active");

        // Remove from active configs
        _activeConfigs[configKey] = false;
        
        // Remove from list
        for (uint256 i = 0; i < _activeConfigList.length; i++) {
            if (_activeConfigList[i] == configKey) {
                _activeConfigList[i] = _activeConfigList[_activeConfigList.length - 1];
                _activeConfigList.pop();
                break;
            }
        }

        // Clear config data
        delete _bridgeConfigs[configKey];
        delete _bridgeTokens[configKey];

        emit BridgeConfigRemoved(sourceChainId, targetChainId);
    }

    event BridgeConfigRemoved(uint256 sourceChainId, uint256 targetChainId);
} 