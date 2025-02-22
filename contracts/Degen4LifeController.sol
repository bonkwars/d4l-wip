// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IDegen4Life.sol";
import "./interfaces/IPoolController.sol";
import "./interfaces/ITokenFactory.sol";
import "./interfaces/IUserProfile.sol";
import "./interfaces/ISocialOracle.sol";
import "./interfaces/ISocialTrading.sol";
import "./Degen4LifeRoles.sol";
import "./interfaces/IVersionController.sol";
import "./modules/SecurityModule.sol";
import "./modules/LiquidityModule.sol";
import "./modules/SocialModule.sol";


// Import interfaces with struct definitions
import "./interfaces/ISecurityModule.sol";
import "./interfaces/ILiquidityModule.sol";
import "./interfaces/ISocialModule.sol";
import "./registry/ContractRegistry.sol";
import "./interfaces/IDegenDEX.sol";
import "./interfaces/IDegenENS.sol";
import "./interfaces/IDegenPredictionMarket.sol";
import "./interfaces/IDexPausable.sol";
import "./interfaces/ITokenComponentFactory.sol";
import "./interfaces/IUserToken.sol";

contract Degen4LifeController is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable 
{
    // Version control
    uint256 public constant CURRENT_VERSION = 1;
    uint256 public version;
    
    // Core system addresses
    address public tokenFactory;
    address public poolController;
    address public feeHandler;
    address public userProfile;
    address public antiBot;
    address public antiRugPull;
    address public dao;
    address public versionController;
    
    // Module addresses
    ISecurityModule public securityModule;
    ILiquidityModule public liquidityModule;
    ISocialModule public socialModule;
    ISocialTrading public socialTradingModule;
    
    // Registry
    ContractRegistry public registry;
    
    // New module interfaces
    IDegenDEX public dex;
    IDegenENS public ens;
    IDegenPredictionMarket public predictionMarket;
    
    // Add TokenComponentFactory
    address public componentFactory;

    // Add token registry mapping
    mapping(address => TokenData) public tokenRegistry;
    
    // Structs
    struct SystemAddresses {
        address tokenFactory;
        address poolController;
        address feeHandler;
        address userProfile;
        address antiBot;
        address antiRugPull;
        address governance;
        address hydraCurve;
        address socialOracle;
        address dao;
        address dex;
        address ens;
        address predictionMarket;
    }

    struct TokenData {
        address creator;
        uint256 creationTimestamp;
        bool securityEnabled;
        uint256 socialScore;
        address associatedPool;
    }
    
    // Events
    event ModulesInitialized(
        address securityModule,
        address liquidityModule,
        address socialModule,
        address socialTradingModule
    );
    event SystemAddressesUpdated(SystemAddresses addresses);
    event ControllerUpgraded(uint256 newVersion);
    event EmergencyShutdown(address indexed triggeredBy);
    event SystemResumed(address indexed triggeredBy);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _registry) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        
        registry = ContractRegistry(_registry);
        version = CURRENT_VERSION;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Degen4LifeRoles.GOVERNANCE_ADMIN, msg.sender);
        _grantRole(Degen4LifeRoles.UPGRADE_ROLE, msg.sender);
    }
    
    function initializeModules(
        address _securityModule,
        address _liquidityModule,
        address _socialModule,
        address _socialTradingModule,
        address _dex,
        address _ens,
        address _predictionMarket
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // In production, prevent reinitialization
        if (block.chainid != 31337) { // 31337 is the chainId for Hardhat Network
            require(
                address(securityModule) == address(0) &&
                address(liquidityModule) == address(0) &&
                address(socialModule) == address(0) &&
                address(socialTradingModule) == address(0) &&
                address(dex) == address(0) &&
                address(ens) == address(0) &&
                address(predictionMarket) == address(0),
                "Modules already initialized"
            );
        }
        
        securityModule = ISecurityModule(_securityModule);
        liquidityModule = ILiquidityModule(_liquidityModule);
        socialModule = ISocialModule(_socialModule);
        socialTradingModule = ISocialTrading(_socialTradingModule);
        dex = IDegenDEX(_dex);
        ens = IDegenENS(_ens);
        predictionMarket = IDegenPredictionMarket(_predictionMarket);
        
        emit ModulesInitialized(
            _securityModule,
            _liquidityModule,
            _socialModule,
            _socialTradingModule
        );
    }
    
    function setSystemAddresses(SystemAddresses calldata addresses) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(addresses.tokenFactory != address(0), "Invalid token factory");
        require(addresses.poolController != address(0), "Invalid pool controller");
        require(addresses.feeHandler != address(0), "Invalid fee handler");
        require(addresses.userProfile != address(0), "Invalid user profile");
        require(addresses.antiBot != address(0), "Invalid anti-bot");
        require(addresses.antiRugPull != address(0), "Invalid anti-rugpull");
        require(addresses.governance != address(0), "Invalid governance");
        require(addresses.hydraCurve != address(0), "Invalid hydra curve");
        require(addresses.socialOracle != address(0), "Invalid social oracle");
        require(addresses.dao != address(0), "Invalid dao");
        require(addresses.dex != address(0), "Invalid dex");
        require(addresses.ens != address(0), "Invalid ens");
        require(addresses.predictionMarket != address(0), "Invalid prediction market");
        
        tokenFactory = addresses.tokenFactory;
        poolController = addresses.poolController;
        feeHandler = addresses.feeHandler;
        userProfile = addresses.userProfile;
        antiBot = addresses.antiBot;
        antiRugPull = addresses.antiRugPull;
        dao = addresses.dao;
        dex = IDegenDEX(addresses.dex);
        ens = IDegenENS(addresses.ens);
        predictionMarket = IDegenPredictionMarket(addresses.predictionMarket);
        
        emit SystemAddressesUpdated(addresses);
    }
    
    function setComponentFactory(address _factory) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_factory != address(0), "Invalid factory address");
        componentFactory = _factory;
    }
    
    // Launchpad Integration Functions
function launchToken(
    string memory name,
    string memory symbol,
    uint256 initialSupply,
    ISecurityModule.SecurityConfig calldata securityConfig,
    ILiquidityModule.PoolParameters calldata poolParams,
    ISocialModule.TokenGateConfig calldata gateConfig
) external payable whenNotPaused returns (address token) {
    // Input validations
    require(bytes(name).length > 0, "Token name cannot be empty");
    require(bytes(symbol).length > 0, "Token symbol cannot be empty");
    require(initialSupply > 0, "Initial supply must be > 0");
    require(securityConfig.maxTransactionAmount > 0, "Max transaction amount must be > 0");
    require(securityConfig.timeWindow > 0, "Time window must be > 0");
    require(securityConfig.maxTransactionsPerWindow > 0, "Max transactions per window must be > 0");
    require(poolParams.initialLiquidity > 0, "Initial liquidity must be > 0");
    require(msg.value >= poolParams.initialLiquidity, "Insufficient ETH for liquidity");
    require(gateConfig.minHoldDuration > 0, "Minimum hold duration must be > 0");

    // System addresses validations
    require(tokenFactory != address(0), "Token factory not set");
    require(componentFactory != address(0), "Component factory not set");
    require(address(dex) != address(0), "DEX not set");
    require(address(ens) != address(0), "ENS not set");
    require(address(predictionMarket) != address(0), "Prediction market not set");

    // Create the token and mint it to the controller so that the controller holds the tokens.
    try ITokenFactory(tokenFactory).createToken(
        name,
        symbol,
        initialSupply,
        address(this), // mint tokens to controller
        0
    ) returns (address newToken) {
        token = newToken;
        
        // Create token components.
        try ITokenComponentFactory(componentFactory).createTokenComponents(token) returns (
            address antiBotInstance,
            address antiRugPullInstance,
            address liquidityModuleInstance,
            address securityModuleInstance
        ) {
            bytes32 tokenType = keccak256(abi.encodePacked(token, name, symbol));
            
            try ISecurityModule(securityModuleInstance).updateSecurityConfig(
                tokenType,
                securityConfig
            ) {
                try socialModule.createTokenGate(
                    token,
                    gateConfig.minHoldAmount,
                    gateConfig.minHoldDuration,
                    gateConfig.requiredLevel,
                    gateConfig.requireVerification,
                    gateConfig.enableTrading,
                    gateConfig.enableStaking
                ) {
                    try IUserProfile(userProfile).recordTokenCreation(msg.sender, token) {
                        // Approve the deployed Liquidity Module (using the controller's address) to spend tokens.
                        uint256 approvalAmount = poolParams.initialLiquidity+301;
                        IERC20(token).approve(address(liquidityModule), type(uint256).max);
                   
                        
                        // Instead of calling initializePool via the interface (which preserves external msg.sender),
                        // we perform a low-level call so that msg.sender becomes the controller.
                        (bool success, bytes memory returnData) = address(liquidityModule).call{value: msg.value}(
                            abi.encodeWithSignature(
                                "initializePool(address,(uint256,uint256,uint256,uint256,uint16,bool),address)",
                                token,
                                poolParams,
                                address(this)
                            )
                        );
                        require(success, string(returnData));
                        
                        // Record token creation in our registry.
                        tokenRegistry[token] = TokenData({
                            creator: msg.sender,
                            creationTimestamp: block.timestamp,
                            securityEnabled: true,
                            socialScore: 0,
                            associatedPool: address(0)
                        });
                        return token;
                    } catch Error(string memory reason) {
                        revert(string(abi.encodePacked("User profile error: ", reason)));
                    } catch {
                        revert("Failed to record token creation in user profile");
                    }
                } catch Error(string memory reason) {
                    revert(string(abi.encodePacked("Social module error: ", reason)));
                } catch {
                    revert("Failed to create token gate in social module");
                }
            } catch Error(string memory reason) {
                revert(string(abi.encodePacked("Security module error: ", reason)));
            } catch {
                revert("Failed to update security configuration");
            }
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Component factory error: ", reason)));
        } catch {
            revert("Failed to create token components");
        }
    } catch Error(string memory reason) {
        revert(string(abi.encodePacked("Token factory error: ", reason)));
    } catch {
        revert("Failed to create token in factory");
    }
}






    
    // Trading Functions
    function validateAndProcessTrade(
        address token,
        address trader,
        uint256 amount,
        bool isOutput
    ) external whenNotPaused returns (bool) {
        require(msg.sender == address(this) || msg.sender == address(socialTradingModule), "Unauthorized");
        // Add your trade validation logic here
        // For example:
        if (isOutput) {
            // Validate output trade
            require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient contract balance");
        } else {
            // Validate input trade
            require(IERC20(token).allowance(trader, address(this)) >= amount, "Insufficient allowance");
            require(IERC20(token).balanceOf(trader) >= amount, "Insufficient balance");
        }
        
        // Process the trade
        if (!isOutput) {
            require(IERC20(token).transferFrom(trader, address(this), amount), "Transfer failed");
        } else {
            require(IERC20(token).transfer(trader, amount), "Transfer failed");
        }

        // Record trade in social module and mirror for copy traders
        _handleSocialTrading(token, trader, amount, isOutput);
        
        return true;
    }

    /**
     * @notice Handles social trading aspects of a trade
     * @param token Token being traded
     * @param trader Trader executing the trade
     * @param amount Trade amount
     * @param isBuy Whether this is a buy trade
     */
    function _handleSocialTrading(
        address token,
        address trader,
        uint256 amount,
        bool isBuy
    ) internal {
        ISocialModule(socialModule).recordTradeAction(token, trader, amount, isBuy);
        
        // Get trader's followers and mirror trade
        address[] memory followers = socialTradingModule.getFollowers(trader);
        
        for (uint i = 0; i < followers.length; i++) {
            address follower = followers[i];
            ISocialTrading.CopyTrading memory copyTrade = socialTradingModule.getCopyTrading(follower, trader);
            
            if (copyTrade.isActive) {
                uint256 mirrorAmount = (amount * copyTrade.amount) / IERC20(token).balanceOf(trader);
                if (mirrorAmount > 0) {
                    // Mirror the trade for the follower - ignore failures
                    if (isBuy) {
                        if (IERC20(token).balanceOf(address(this)) >= mirrorAmount) {
                            IERC20(token).transfer(follower, mirrorAmount);
                        }
                    } else {
                        if (IERC20(token).allowance(follower, address(this)) >= mirrorAmount &&
                            IERC20(token).balanceOf(follower) >= mirrorAmount) {
                            IERC20(token).transferFrom(follower, address(this), mirrorAmount);
                        }
                    }
                }
            }
        }
    }
    
    // Emergency Controls
    function pauseAllModules() external onlyRole(DEFAULT_ADMIN_ROLE) {
        securityModule.pause();
        liquidityModule.pause();
        socialModule.pause();
        
        // Pause new modules
        if (address(dex) != address(0)) {
            IDexPausable(address(dex)).pause();
        }
        if (address(ens) != address(0)) {
            IDexPausable(address(ens)).pause();
        }
        if (address(predictionMarket) != address(0)) {
            IDexPausable(address(predictionMarket)).pause();
        }
        _pause();
    }
    
    function unpauseAllModules() external onlyRole(DEFAULT_ADMIN_ROLE) {
        securityModule.unpause();
        liquidityModule.unpause();
        socialModule.unpause();
        
        // Unpause new modules using IDexPausable interface
        if (address(dex) != address(0)) {
            IDexPausable(address(dex)).unpause();
        }
        if (address(ens) != address(0)) {
            IDexPausable(address(ens)).unpause();
        }
        if (address(predictionMarket) != address(0)) {
            IDexPausable(address(predictionMarket)).unpause();
        }
        _unpause();
    }

    function getSystemState() external view returns (
        address[] memory allTokens,
        address[] memory activePools,
        uint256 totalUsers
    ) {
        allTokens = ITokenFactory(tokenFactory).getAllTokens();

        activePools = IPoolController(poolController).getActivePools();


        totalUsers = IUserProfile(userProfile).totalUsers();
    }

    // Social Amplification (FEATURES.md line 19-24)
    function updateSocialOracle(address newOracle) external onlyRole(Degen4LifeRoles.GOVERNANCE_ADMIN) {
        // Implementation needed
    }

    // Viral Mechanics (UserProfile.sol startLine: 2006, endLine: 2371)
    function trackSocialEngagement(address token) external {
        // Implementation needed
    }

    // Risk Management (FEATURES.md line 91-94)
    function emergencyPauseSystem(bool pauseAll) external onlyRole(Degen4LifeRoles.SECURITY_ADMIN) {
        if(pauseAll) {
            _pause();
            IPoolController(poolController).pauseAll();

        } else {
            _unpause();
            IPoolController(poolController).unpauseAll();
        }
    }

    function getTokenData(address token) external view returns (TokenData memory) {
        // Implementation needed
    }

    function updateTokenSecurity(address token, bool enabled) external onlyRole(Degen4LifeRoles.SECURITY_ADMIN) {
        // Implementation needed
    }

    event DependencyUpdated(bytes32 indexed component, address newAddress);

    function _pause() internal override {
        super._pause();
    }

    function _unpause() internal override {
        super._unpause();
    }

    function proposeUpgrade(
        address newImplementation, 
        string calldata newVersion
    ) external onlyRole(Degen4LifeRoles.GOVERNANCE_ADMIN) {
        // Implementation needed
    }

    event UpgradeProposed(
        address indexed newImplementation,
        string version,
        uint256 timestamp
    );

    function upgradeToVersion(uint256 newVersion) external onlyRole(Degen4LifeRoles.UPGRADE_ROLE) {
        require(newVersion > version, "Invalid version");
        require(newVersion <= CURRENT_VERSION, "Version not available");
        
        // Pause the system during upgrade
        if (!paused()) {
            _pause();
        }
        
        version = newVersion;
        emit ControllerUpgraded(newVersion);
        
        // Resume the system after upgrade
        _unpause();
    }

    function emergencyShutdown() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        
        // Pause all modules
        securityModule.pause();
        liquidityModule.pause();
        socialModule.pause();
        
        emit EmergencyShutdown(msg.sender);
    }
    
    function resumeSystem() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(paused(), "System not paused");
        
        // Resume all modules
        securityModule.unpause();
        liquidityModule.unpause();
        socialModule.unpause();
        
        _unpause();
        emit SystemResumed(msg.sender);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(Degen4LifeRoles.UPGRADE_ROLE) {}

    // DEX Functions
    function createPool(
        address token0,
        address token1,
        uint256 fee
    ) external whenNotPaused onlyRole(Degen4LifeRoles.POOL_MANAGER) returns (address) {
        return dex.createPool(token0, token1, fee);
    }
    
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external whenNotPaused returns (uint256, uint256, uint256) {
        return dex.addLiquidity(
            token0,
            token1,
            amount0Desired,
            amount1Desired,
            amount0Min,
            amount1Min,
            to,
            deadline
        );
    }
    
    function swap(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external whenNotPaused returns (uint256[] memory) {
        // Handle input token
        require(IERC20(path[0]).allowance(msg.sender, address(this)) >= amountIn, "Insufficient allowance");
        require(IERC20(path[0]).balanceOf(msg.sender) >= amountIn, "Insufficient balance");
        require(IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        
        // Record trade and handle social trading
        _handleSocialTrading(path[0], msg.sender, amountIn, false);
        
        // Execute swap
        uint256[] memory amounts = dex.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
        
        // Record output trade
        _handleSocialTrading(path[path.length - 1], msg.sender, amounts[amounts.length - 1], true);
        
        return amounts;
    }
    
    // ENS Functions
    function registerName(
        string calldata name,
        address owner,
        uint256 duration
    ) external whenNotPaused {
        ens.registerName(name, owner, duration);
    }
    
    function setResolver(
        bytes32 nameHash,
        address resolver
    ) external whenNotPaused {
        require(ens.getOwner(nameHash) == msg.sender, "Not name owner");
        ens.setResolver(nameHash, resolver);
    }
    
    function transferName(
        bytes32 nameHash,
        address newOwner
    ) external whenNotPaused {
        require(ens.getOwner(nameHash) == msg.sender, "Not name owner");
        ens.transferName(nameHash, newOwner);
    }
    
    function renewName(
        bytes32 nameHash,
        uint256 duration
    ) external whenNotPaused {
        require(!ens.isExpired(nameHash), "Name expired");
        ens.renewName(nameHash, duration);
    }

    // Prediction Market Functions
    function createMarket(
        string calldata question,
        uint256 expiresAt,
        uint256 resolutionWindow,
        uint256 minBetAmount,
        uint256 maxBetAmount,
        uint256 creatorStake
    ) external whenNotPaused returns (uint256) {
        return predictionMarket.createMarket(
            question,
            expiresAt,
            resolutionWindow,
            minBetAmount,
            maxBetAmount,
            creatorStake
        );
    }
    
    function takePosition(
        uint256 marketId,
        bool isYes,
        uint256 amount
    ) external whenNotPaused {
        predictionMarket.takePosition(marketId, isYes, amount);
    }
    
    function resolveMarket(
        uint256 marketId,
        IDegenPredictionMarket.MarketOutcome outcome
    ) external whenNotPaused onlyRole(Degen4LifeRoles.ORACLE_ROLE) {
        predictionMarket.resolveMarket(marketId, outcome);
    }
    
    function claimRewards(uint256 marketId) external whenNotPaused returns (uint256) {
        return predictionMarket.claimRewards(marketId);
    }
    
    function cancelMarket(
        uint256 marketId,
        string calldata reason
    ) external whenNotPaused onlyRole(Degen4LifeRoles.GOVERNANCE_ADMIN) {
        predictionMarket.cancelMarket(marketId, reason);
    }
} 