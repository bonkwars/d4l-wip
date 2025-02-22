// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../interfaces/ITokenFactory.sol";
import "../interfaces/IUserToken.sol";
import "../interfaces/IAntiBot.sol";
import "../interfaces/IAntiRugPull.sol";
import "../interfaces/IUserProfile.sol";
import "../tokens/UserToken.sol";
import "../tokenomics/tokenomics.sol";
import "../registry/ContractRegistry.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/// @title TokenFactory
/// @notice Factory contract for creating standardized tokens
/// @dev Creates tokens with standardized features and security measures
contract TokenFactory is Initializable, OwnableUpgradeable, ITokenFactory {
    // State variables
    address public immutable tokenImplementation;
    address public immutable WETH;
    address public antiBot;
    address public antiRugPull;
    address public userProfile;
    address public poolController;
    uint256 public creationFee;
    address public tokenomics;
    address public communityWallet;
    address public teamWallet;
    address public dexLiquidityWallet;
    address public treasuryWallet;
    address public marketingWallet;
    address public cexLiquidityWallet;
    ContractRegistry public registry;
    
    // Mappings
    mapping(address => TokenConfig) public tokenConfigs;
    mapping(address => bool) public isFactoryToken;
    
    // Events
    event UpgradeProposed(address indexed newImplementation, string version, uint256 timestamp);
    event TokenCreationStep(string step, string message);
    event TokenCreationError(string step, string error);
    
    // Add free tier limits
    uint256 public constant FREE_TIER_MAX_SUPPLY = 1_000_000_000 * 1e18;  // 1B tokens
    uint256 public constant FREE_TIER_MAX_TOKENS = 100;    // Max free tokens per address
    
    // Track free tier usage
    mapping(address => uint256) public freeTokensCreated;

    // Add missing constants and state variables
    uint256 private constant FEE_BPS = 10000;
    bool private _locked;  // For reentrancy guard

    constructor(address _weth) {
        require(_weth != address(0), "Invalid WETH");
        tokenImplementation = address(new UserToken());
        WETH = _weth;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    function _createTokenWithCreator(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        bool isFree,
        address creator,
        uint256 initialLiquidity
    ) internal returns (address token) {
        require(bytes(name).length > 0 && bytes(name).length <= 32, "Invalid name length");
        require(bytes(symbol).length > 0 && bytes(symbol).length <= 8, "Invalid symbol length");
        require(initialSupply > 0, "Initial supply must be positive");
        require(creator != address(0), "Creator address cannot be zero");

        bytes32 salt = keccak256(abi.encodePacked(creator, block.timestamp, initialSupply));
        token = Clones.cloneDeterministic(tokenImplementation, salt);
        
        IUserToken(token).initialize(
            name,
            symbol,
            creator,
            creationFee,
            address(0), // tokenomics will be set later
            WETH
        );

        tokenConfigs[token] = TokenConfig({
            maxSupply: uint128(initialSupply),
            maxTxAmount: uint64(initialSupply / 100),  // 1% max tx
            maxWalletAmount: uint64(initialSupply / 50),  // 2% max wallet
            mintable: false,  // Immutable supply for trust
            burnable: true,   // Allow burning
            pausable: true,   // Safety feature
            transferDelay: isFree ? 1 hours : 0,  // Anti-bot for free tier
            feeRecipient: address(this),
            buyFee: 300,    // 3%
            sellFee: 300,   // 3%
            transferFee: 100 // 1%
        });

        isFactoryToken[token] = true;
        
        if (antiBot != address(0)) {
            IAntiBot(antiBot).whitelistAddress(token, true);
        }
        if (antiRugPull != address(0)) {
            IAntiRugPull(antiRugPull).setWhitelisted(token, token, true);
        }
        if (userProfile != address(0)) {
            IUserProfile(userProfile).recordTokenCreation(creator, token);
        }

        emit TokenCreated(token, creator, name, symbol, initialSupply);
        emit TokenConfigured(token, creator, tokenConfigs[token]);
        
        return token;
    }

    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) external override returns (address) {
        return _createTokenWithCreator(name, symbol, initialSupply, false, msg.sender, 0);
    }

    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address creator,
        uint256 initialLiquidity
    ) external override returns (address) {
        return _createTokenWithCreator(name, symbol, initialSupply, false, creator, initialLiquidity);
    }

    function createToken(
        TokenCreationParams calldata params
    ) external payable override returns (address) {
        require(msg.value >= creationFee, "Insufficient creation fee");
        return _createTokenWithCreator(
            params.name,
            params.symbol,
            params.initialSupply,
            false,
            msg.sender,
            params.initialLiquidityAmount
        );
    }

    function calculateBasePrice(
        uint256 /* totalSupply */,
        uint8 /* decimals */,
        uint256 /* initialLiquidityAmount */,
        uint256 initialLiquidityPrice
    ) external pure returns (uint256) {
        return initialLiquidityPrice;
    }

    function verifyFalconSignature(address /* creator */, bytes memory /* signature */) external pure override returns (bool) {
        return true; // Placeholder for future implementation
    }

    function getCreationFee() external pure override returns (uint256) {
        return 0; // Free for now
    }

    function setCreationFee(uint256 newFee) external override onlyOwner {
        creationFee = newFee;
    }

    function getTaxConfiguration() external pure override returns (
        uint256 communityShare,
        uint256 teamShare,
        uint256 liquidityShare,
        uint256 treasuryShare,
        uint256 marketingShare,
        uint256 cexLiquidityShare
    ) {
        return (2500, 2000, 3000, 1000, 1000, 500);
    }

    function setController(address controller) external override onlyOwner {
        require(controller != address(0), "Invalid controller");
        poolController = controller;
    }

    function getAllTokens() external pure override returns (address[] memory) {
        return new address[](0); // Placeholder - implement token tracking if needed
    }

    // Add setter functions for dependencies
    function setAntiBot(address _antiBot) external onlyOwner {
        require(_antiBot != address(0), "Invalid antiBot");
        antiBot = _antiBot;
    }

    function setAntiRugPull(address _antiRugPull) external onlyOwner {
        require(_antiRugPull != address(0), "Invalid antiRugPull");
        antiRugPull = _antiRugPull;
    }

    function setUserProfile(address _userProfile) external onlyOwner {
        require(_userProfile != address(0), "Invalid userProfile");
        userProfile = _userProfile;
    }

    function setTokenImplementation(address _implementation) external override onlyOwner {
        require(_implementation != address(0), "Invalid implementation");
        // Note: Since tokenImplementation is immutable, we can't actually change it
        // This function is kept for interface compatibility
        emit UpgradeProposed(_implementation, "1.0.0", block.timestamp);
    }

    function setPoolController(address _poolController) external override onlyOwner {
        require(_poolController != address(0), "Invalid controller");
        poolController = _poolController;
        console.log("Pool controller set to:", poolController);
    }

    // Helper functions for debug output
    function addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3+i*2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    function uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function updateTokenConfig(
        address token,
        TokenConfig calldata newConfig
    ) external override {
        require(isFactoryToken[token], "Not a factory token");
        require(msg.sender == IUserToken(token).owner(), "Not token owner");
        
        tokenConfigs[token] = newConfig;
        emit TokenConfigured(token, msg.sender, newConfig);
    }

    function isD4LToken(address token) external view override returns (bool) {
        return isFactoryToken[token];
    }
}

/// @title DegenToken
/// @notice Standard ERC20 token with additional features
contract DegenToken is ERC20, Ownable {
    // Access control
    mapping(address => bool) public minters;
    mapping(address => bool) public burners;
    mapping(address => bool) public pausers;
    
    // Token configuration
    uint256 public maxSupply;
    uint256 public maxTxAmount;
    uint256 public maxWalletAmount;
    uint256 public transferDelay;
    address public feeRecipient;
    uint16 public buyFee;
    uint16 public sellFee;
    uint16 public transferFee;
    
    // State variables
    bool public paused;
    mapping(address => uint256) public lastTransfer;
    
    // Events
    event Paused(address indexed pauser);
    event Unpaused(address indexed pauser);
    event FeeCollected(address indexed from, address indexed to, uint256 amount);
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _owner,
        uint256 initialSupply
    ) ERC20(_name, _symbol) Ownable(_owner) {
        _transferOwnership(_owner);
        minters[_owner] = true;
        burners[_owner] = true;
        _mint(_owner, initialSupply);
    }
    
    // Modifiers
    modifier whenNotPaused() {
        require(!paused, "Token is paused");
        _;
    }
    
    modifier onlyMinter() {
        require(minters[msg.sender], "Not a minter");
        _;
    }
    
    modifier onlyBurner() {
        require(burners[msg.sender], "Not a burner");
        _;
    }
    
    modifier onlyPauser() {
        require(pausers[msg.sender], "Not a pauser");
        _;
    }
    
    // Transfer override with limits and fees
    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        require(amount <= maxTxAmount, "Exceeds max tx");
        require(balanceOf(to) + amount <= maxWalletAmount, "Exceeds wallet max");
        require(block.timestamp >= lastTransfer[msg.sender] + transferDelay, "Transfer delay");
        
        uint256 fee = (amount * transferFee) / 10000;
        if (fee > 0 && feeRecipient != address(0)) {
            super.transfer(feeRecipient, fee);
            emit FeeCollected(msg.sender, to, fee);
        }
        
        lastTransfer[msg.sender] = block.timestamp;
        return super.transfer(to, amount - fee);
    }
    
    // Configuration functions
    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        maxSupply = _maxSupply;
    }
    
    function setTransferDelay(uint256 _delay) external onlyOwner {
        transferDelay = _delay;
    }
    
    function setMaxTxAmount(uint256 _maxTxAmount) external onlyOwner {
        maxTxAmount = _maxTxAmount;
    }
    
    function setMaxWalletAmount(uint256 _maxWalletAmount) external onlyOwner {
        maxWalletAmount = _maxWalletAmount;
    }
    
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }
    
    function setFees(uint16 _buyFee, uint16 _sellFee, uint16 _transferFee) external onlyOwner {
        require(_buyFee <= 1000 && _sellFee <= 1000 && _transferFee <= 1000, "Max 10%");
        buyFee = _buyFee;
        sellFee = _sellFee;
        transferFee = _transferFee;
    }
    
    // Access control functions
    function grantMinter(address minter) external onlyOwner {
        minters[minter] = true;
    }
    
    function revokeMinter(address minter) external onlyOwner {
        minters[minter] = false;
    }
    
    function grantBurner(address burner) external onlyOwner {
        burners[burner] = true;
    }
    
    function revokeBurner(address burner) external onlyOwner {
        burners[burner] = false;
    }
    
    function grantPauser(address pauser) external onlyOwner {
        pausers[pauser] = true;
    }
    
    function revokePauser(address pauser) external onlyOwner {
        pausers[pauser] = false;
    }
    
    // Token operations
    function mint(address to, uint256 amount) external onlyMinter {
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external onlyBurner {
        _burn(from, amount);
    }
    
    function pause() external onlyPauser {
        paused = true;
        emit Paused(msg.sender);
    }
    
    function unpause() external onlyPauser {
        paused = false;
        emit Unpaused(msg.sender);
    }
}