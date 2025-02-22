// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@prb/math/src/UD60x18.sol";

contract PumpMechanics is Ownable, ReentrancyGuard, Pausable {
    // Constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_PUMP_MULTIPLIER = 5e18; // 5x
    uint256 public constant MIN_COOLDOWN = 1 hours;
    uint256 public constant MAX_COOLDOWN = 24 hours;

    // Structs
    struct PumpConfig {
        uint256 velocityThreshold;    // Price change velocity threshold
        uint256 cooldownPeriod;       // Cooldown after pump detection
        uint256 maxFeeMultiplier;     // Maximum fee increase during pump
        uint256 recoveryRate;         // Rate at which fees return to normal
    }

    struct PumpState {
        uint256 lastPrice;
        uint256 lastUpdateTime;
        uint256 currentMultiplier;
        uint256 pumpEndTime;
        bool isPumping;
    }

    // State variables
    mapping(address => PumpConfig) public pumpConfigs;
    mapping(address => PumpState) public pumpStates;
    
    // Events
    event PumpDetected(address indexed token, uint256 multiplier);
    event PumpResolved(address indexed token);
    event ConfigUpdated(address indexed token, PumpConfig config);

    constructor() Ownable(msg.sender) {
        _initializeDefaultConfig();
    }

    function _initializeDefaultConfig() private {
        PumpConfig memory defaultConfig = PumpConfig({
            velocityThreshold: 0.1e18,    // 10% per hour
            cooldownPeriod: 6 hours,
            maxFeeMultiplier: 3e18,       // 3x
            recoveryRate: 0.1e18          // 10% per hour
        });

        pumpConfigs[address(0)] = defaultConfig; // Default config
    }

    function updatePumpConfig(
        address token,
        PumpConfig calldata config
    ) external onlyOwner {
        require(config.velocityThreshold > 0, "Invalid threshold");
        require(config.cooldownPeriod >= MIN_COOLDOWN, "Cooldown too short");
        require(config.cooldownPeriod <= MAX_COOLDOWN, "Cooldown too long");
        require(config.maxFeeMultiplier <= MAX_PUMP_MULTIPLIER, "Multiplier too high");
        
        pumpConfigs[token] = config;
        emit ConfigUpdated(token, config);
    }

    function checkAndUpdatePumpStatus(
        address token,
        uint256 currentPrice
    ) external nonReentrant whenNotPaused returns (bool) {
        PumpState storage state = pumpStates[token];
        PumpConfig memory config = pumpConfigs[token];
        
        if (config.velocityThreshold == 0) {
            config = pumpConfigs[address(0)]; // Use default config
        }

        uint256 timeElapsed = block.timestamp - state.lastUpdateTime;
        if (timeElapsed == 0) return state.isPumping;

        // Calculate price velocity
        UD60x18 priceChange = UD60x18.wrap(currentPrice).sub(UD60x18.wrap(state.lastPrice));
        UD60x18 velocity = priceChange.div(UD60x18.wrap(timeElapsed));

        // Check for pump condition
        if (velocity.unwrap() > config.velocityThreshold) {
            state.isPumping = true;
            state.currentMultiplier = config.maxFeeMultiplier;
            state.pumpEndTime = block.timestamp + config.cooldownPeriod;
            emit PumpDetected(token, config.maxFeeMultiplier);
        } else if (state.isPumping && block.timestamp > state.pumpEndTime) {
            state.isPumping = false;
            state.currentMultiplier = PRECISION;
            emit PumpResolved(token);
        } else if (state.isPumping) {
            // Gradually reduce multiplier
            uint256 timeFromPump = block.timestamp - (state.pumpEndTime - config.cooldownPeriod);
            UD60x18 reduction = UD60x18.wrap(config.recoveryRate)
                .mul(UD60x18.wrap(timeFromPump))
                .div(UD60x18.wrap(config.cooldownPeriod));
            
            state.currentMultiplier = UD60x18.wrap(config.maxFeeMultiplier)
                .sub(reduction)
                .unwrap();
            
            if (state.currentMultiplier < PRECISION) {
                state.currentMultiplier = PRECISION;
            }
        }

        // Update state
        state.lastPrice = currentPrice;
        state.lastUpdateTime = block.timestamp;

        return state.isPumping;
    }

    function getCurrentMultiplier(address token) external view returns (uint256) {
        return pumpStates[token].currentMultiplier;
    }

    function isPumping(address token) external view returns (bool) {
        return pumpStates[token].isPumping;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
} 