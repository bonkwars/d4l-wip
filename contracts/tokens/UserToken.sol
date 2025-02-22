// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/ITokenomics.sol";
import "../interfaces/ITokenFactory.sol";
import "../factory/TokenFactory.sol";

contract UserToken is ERC20Upgradeable, OwnableUpgradeable {
    // Packed configuration (1 storage slot)
    struct TokenConfig {
        uint128 maxSupply;
        uint64 maxTx;
        uint64 maxWallet;
        uint32 cooldown;
        uint16 buyTax;
        uint16 sellTax;
        uint8 flags; // bit 0: mintable, bit 1: burnable, bit 2: paused
    }
    
    TokenConfig private _config;
    address public factory;
    address public WETH;
    address public poolController_;  // Added pool controller storage
    address public liquidityProvider;
    uint256 public creationFee;
    ITokenomics public tokenomics;
    
    // Add wallet addresses
    address public communityWallet;
    address public teamWallet;
    address public dexLiquidityWallet;
    address public treasuryWallet;
    address public marketingWallet;
    address public cexLiquidityWallet;
    
    event FeesCollected(address indexed payer, uint256 amount);
    event TokenomicsUpdated(address indexed tokenomics);
    event WalletsConfigured(
        address communityWallet,
        address teamWallet,
        address dexLiquidityWallet,
        address treasuryWallet,
        address marketingWallet,
        address cexLiquidityWallet
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address owner,
        uint256 _creationFee,
        address _tokenomics,
        address _weth
    ) external initializer {
        require(msg.sender == factory || factory == address(0), "Only factory can initialize");
        require(owner != address(0), "Invalid owner");
        require(_tokenomics != address(0), "Invalid tokenomics");
        require(_weth != address(0), "Invalid WETH address");
        __ERC20_init(name, symbol);
        __Ownable_init(owner); // Initialize with the owner address
        
        factory = msg.sender;
        WETH = _weth;
     
        
        _config = TokenConfig({
            maxSupply: 0,
            maxTx: 0,
            maxWallet: 0,
            cooldown: 0,
            buyTax: 0,
            sellTax: 0,
            flags: 0
        });
        creationFee = _creationFee;
        tokenomics = ITokenomics(_tokenomics);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Skip fees for factory and pool controller
        if (msg.sender == factory || msg.sender == poolController_ || msg.sender == liquidityProvider) {
            super._update(from, to, amount);
            return;
        }

        if (from != address(0) && to != address(0)) { // Regular transfer
            uint256 fees = tokenomics.calculateTotalFees(amount);
            uint256 burnAmount = tokenomics.calculateBurn(amount);
            
            // Handle burns first
            if (burnAmount > 0) {
                super._update(from, address(0), burnAmount);
            }
            
            // Handle fees
            if (fees > 0) {
                // Community wallet
                uint256 communityAmount = tokenomics.calculateCommunityWallet(amount);
                if (communityAmount > 0) {
                    super._update(from, communityWallet, communityAmount);
                }
                
                // Team wallet
                uint256 teamAmount = tokenomics.calculateTeamWallet(amount);
                if (teamAmount > 0) {
                    super._update(from, teamWallet, teamAmount);
                }
                
                // DEX liquidity
                uint256 dexAmount = tokenomics.calculateDEXLiquidity(amount);
                if (dexAmount > 0) {
                    super._update(from, dexLiquidityWallet, dexAmount);
                }
                
                // Treasury
                uint256 treasuryAmount = tokenomics.calculateTreasuryInitiative(amount);
                if (treasuryAmount > 0) {
                    super._update(from, treasuryWallet, treasuryAmount);
                }
                
                // Marketing
                uint256 marketingAmount = tokenomics.calculateMarketingWallet(amount);
                if (marketingAmount > 0) {
                    super._update(from, marketingWallet, marketingAmount);
                }
                
                // CEX liquidity
                uint256 cexAmount = tokenomics.calculateCEXLiquidity(amount);
                if (cexAmount > 0) {
                    super._update(from, cexLiquidityWallet, cexAmount);
                }
            }
            
            // Transfer remaining amount
            uint256 netAmount = amount - fees - burnAmount;
            super._update(from, to, netAmount);
        } else {
            super._update(from, to, amount); // Mint/burn, no fees
        }
    }

    function payFees(uint256 amount) external {
        IERC20(WETH).transferFrom(msg.sender, address(this), amount);
        emit FeesCollected(msg.sender, amount);
    }

    function withdrawFees(address recipient) external onlyOwner {
        uint256 balance = IERC20(WETH).balanceOf(address(this));
        IERC20(WETH).transfer(recipient, balance);
    }

    function updateTokenomics(address _tokenomics) external onlyOwner {
        require(_tokenomics != address(0), "Invalid tokenomics");
        tokenomics = ITokenomics(_tokenomics);
        emit TokenomicsUpdated(_tokenomics);
    }

    function configure(
        uint256 maxSupply,
        uint256 transferDelay,
        uint256 maxTxAmount,
        uint256 maxWalletAmount
    ) external {
        require(msg.sender == factory || msg.sender == owner(), "Unauthorized");
        require(maxSupply > 0, "Invalid max supply");
        require(maxTxAmount > 0 && maxTxAmount <= maxSupply, "Invalid max tx amount");
        require(maxWalletAmount > 0 && maxWalletAmount <= maxSupply, "Invalid max wallet amount");
        
        _config.maxSupply = uint128(maxSupply);
        _config.maxTx = uint64(maxTxAmount);
        _config.maxWallet = uint64(maxWalletAmount);
        _config.cooldown = uint32(transferDelay);
    }

    // Second configure function for tokenomics settings
    function configure(
        address _communityWallet,
        address _teamWallet,
        address _dexLiquidityWallet,
        address _treasuryWallet,
        address _marketingWallet,
        address _cexLiquidityWallet
    ) external {
        require(msg.sender == factory || msg.sender == owner(), "Unauthorized");
        require(_communityWallet != address(0), "Invalid community wallet");
        require(_teamWallet != address(0), "Invalid team wallet");
        require(_dexLiquidityWallet != address(0), "Invalid DEX liquidity wallet");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        require(_marketingWallet != address(0), "Invalid marketing wallet");
        require(_cexLiquidityWallet != address(0), "Invalid CEX liquidity wallet");
        
        communityWallet = _communityWallet;
        teamWallet = _teamWallet;
        dexLiquidityWallet = _dexLiquidityWallet;
        treasuryWallet = _treasuryWallet;
        marketingWallet = _marketingWallet;
        cexLiquidityWallet = _cexLiquidityWallet;
        
        emit WalletsConfigured(
            _communityWallet,
            _teamWallet,
            _dexLiquidityWallet,
            _treasuryWallet,
            _marketingWallet,
            _cexLiquidityWallet
        );
    }

    // Function to mint tokens, only callable by the factory during initialization
    function mint(address to, uint256 amount) external {
        require(msg.sender == factory, "Only factory can mint");
        _mint(to, amount);
    }

    // Override approve to allow factory and controller to approve on behalf of creator
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address approver = _msgSender();
        _approve(approver, spender, amount);
        return true;
    }

    // Override transfer to use _update
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _update(msg.sender, to, amount);
        return true;
    }

    // Override transferFrom to handle factory and controller transfers
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        // If called by factory or controller, bypass allowance check
        if (spender == factory || spender == poolController_ || spender == liquidityProvider) {
            _update(from, to, amount);
        } else {
            uint256 currentAllowance = allowance(from, spender);
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(from, spender, currentAllowance - amount);
            }
            _update(from, to, amount);
        }
        return true;
    }

    // Special function for factory transfers
    function factoryTransfer(address from, address to, uint256 amount) external returns (bool) {
        require(msg.sender == factory || msg.sender == poolController_, "Only factory or controller can call");
        _update(from, to, amount);
        return true;
    }

    // Get pool controller address
    function poolController() external view returns (address) {
        return poolController_;
    }

    // Function to set the pool controller address
    function setPoolController(address _poolController) external {
        require(msg.sender == factory || msg.sender == owner(), "Unauthorized");
        require(_poolController != address(0), "Invalid pool controller");
        poolController_ = _poolController;
    }

    function setLiquidityProvider(address _liquidityProvider) external {
        require(msg.sender == factory || msg.sender == owner(), "Unauthorized");
        require(_liquidityProvider != address(0), "Invalid liquidity provider");
        liquidityProvider = _liquidityProvider;
    }
} 