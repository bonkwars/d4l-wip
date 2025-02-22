// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IUserToken.sol";
import "../interfaces/IAntiBot.sol";
import "../interfaces/IAntiRugPull.sol";
import "../interfaces/IHydraCurve.sol";
import "../interfaces/ITokenMetadata.sol";

abstract contract AbstractDegen4LifeToken is ERC20, Ownable, IUserToken {
    IAntiBot public antiBot;
    IAntiRugPull public antiRug;
    IHydraCurve public hydraCurve;
    ITokenMetadata public tokenMetadata;
    address public immutable factory;

    TaxInfo public taxInfo;
    address public poolAddress;
    bool public antiBotEnabled;
    bool public antiRugEnabled;

    mapping(bytes32 => address) public taxRecipients;

    event TaxConfigurationUpdated(TaxInfo newConfig);
    event SecurityFeaturesUpdated(bool antiBotEnabled, bool antiRugEnabled);

    // Add pause state
    bool public paused;
    
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);

    // Add max transaction limit
    uint256 public maxTransactionAmount;
    
    event MaxTransactionAmountUpdated(uint256 newAmount);

    // Add timelock for critical operations
    struct TimelockOperation {
        bytes32 operationId;
        uint256 timestamp;
        bool executed;
    }

    uint256 private constant TIMELOCK_DELAY = 2 days;
    mapping(bytes32 => TimelockOperation) private _timelockOperations;

    event OperationQueued(bytes32 indexed operationId, uint256 executeTime);
    event OperationExecuted(bytes32 indexed operationId);

    // Add maximum supply cap
    uint256 public immutable maxSupply;

    // Add tax recipient validation
    mapping(bytes32 => bool) private _validTaxTypes;
    
    event TaxRecipientUpdated(string indexed taxType, address recipient);
    event TaxTypeAdded(string indexed taxType);
    event TaxTypeRemoved(string indexed taxType);

    // Add maximum tax limits
    uint256 private constant MAX_TAX_PERCENTAGE = 10; // 10%
    uint256 private constant MAX_TOTAL_SHARES = 100; // 100%

    // Add tax recipient validation
    mapping(address => bool) private _usedTaxRecipients;
    uint256 private constant MAX_TAX_RECIPIENTS = 10;
    uint256 private _totalTaxRecipients;

    modifier whenNotPaused() {
        require(!paused, "Token is paused");
        _;
    }

    modifier timelocked(bytes32 operationId) {
        TimelockOperation storage operation = _timelockOperations[operationId];
        require(operation.timestamp > 0, "Operation not queued");
        require(block.timestamp >= operation.timestamp + TIMELOCK_DELAY, "Timelock not expired");
        require(!operation.executed, "Operation already executed");
        operation.executed = true;
        _;
        emit OperationExecuted(operationId);
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address antiBot_,
        address antiRug_,
        address hydraCurve_,
        address tokenMetadata_,
        uint256 maxSupply_,
        address factory_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        require(maxSupply_ > 0, "Invalid max supply");
        maxSupply = maxSupply_;
        antiBot = IAntiBot(antiBot_);
        antiRug = IAntiRugPull(antiRug_);
        hydraCurve = IHydraCurve(hydraCurve_);
        tokenMetadata = ITokenMetadata(tokenMetadata_);
        factory = factory_;
        _initializeTaxTypes();
    }

    /// @notice Modifier to check for bot activity
    modifier notBot(address account, uint256 amount) {
        require(!antiBotEnabled || !antiBot.isBot(account, amount), "Bot detected");
        _;
    }

    /// @notice Modifier to check for rug pull protection
    modifier rugProtected(address seller, uint256 amount) {
        if (antiRugEnabled) {
            (bool allowed, string memory reason) = antiRug.canSell(seller, amount);
            require(allowed, reason);
        }
        _;
    }

    /// @notice Updates the tax configuration
    /// @param newTaxInfo New tax configuration
    function updateTaxInfo(TaxInfo calldata newTaxInfo) 
        external 
        timelocked(keccak256("updateTaxInfo")) 
        onlyOwner 
    {
        // Validate individual shares
        require(newTaxInfo.communityShare <= MAX_TAX_PERCENTAGE, "Community share too high");
        require(newTaxInfo.teamShare <= MAX_TAX_PERCENTAGE, "Team share too high");
        require(newTaxInfo.liquidityShare <= MAX_TAX_PERCENTAGE, "Liquidity share too high");
        require(newTaxInfo.treasuryShare <= MAX_TAX_PERCENTAGE, "Treasury share too high");
        require(newTaxInfo.marketingShare <= MAX_TAX_PERCENTAGE, "Marketing share too high");
        require(newTaxInfo.cexLiquidityShare <= MAX_TAX_PERCENTAGE, "CEX liquidity share too high");

        // Validate total shares
        uint256 totalShares = newTaxInfo.communityShare +
            newTaxInfo.teamShare +
            newTaxInfo.liquidityShare +
            newTaxInfo.treasuryShare +
            newTaxInfo.marketingShare +
            newTaxInfo.cexLiquidityShare;
        
        require(totalShares == MAX_TOTAL_SHARES, "Total shares must be 100%");

        taxInfo = newTaxInfo;
        emit TaxConfigurationUpdated(newTaxInfo);
    }

    /// @notice Updates security feature settings
    /// @param enableAntiBot Whether to enable anti-bot protection
    /// @param enableAntiRug Whether to enable anti-rug protection
    function updateSecurityFeatures(bool enableAntiBot, bool enableAntiRug) 
        external 
        timelocked(keccak256("updateSecurityFeatures")) 
        onlyOwner 
    {
        antiBotEnabled = enableAntiBot;
        antiRugEnabled = enableAntiRug;
        emit SecurityFeaturesUpdated(enableAntiBot, enableAntiRug);
    }

    /// @notice Calculates tax amount for a transfer
    /// @param amount The transfer amount
    /// @return The tax amount to be deducted
    function calculateTax(uint256 amount) public view returns (uint256) {
        return (amount * 3) / 100; // 3% tax
    }

    // Add safe transfer helper
    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");
        
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Transfer failed"
        );
    }

    // Add tax distribution validation
    function _validateTaxDistribution(uint256 taxAmount) internal view returns (bool) {
        uint256 communityAmount = (taxAmount * taxInfo.communityShare) / 100;
        uint256 teamAmount = (taxAmount * taxInfo.teamShare) / 100;
        uint256 liquidityAmount = (taxAmount * taxInfo.liquidityShare) / 100;
        uint256 treasuryAmount = (taxAmount * taxInfo.treasuryShare) / 100;
        uint256 marketingAmount = (taxAmount * taxInfo.marketingShare) / 100;
        uint256 cexLiquidityAmount = (taxAmount * taxInfo.cexLiquidityShare) / 100;

        // Validate all recipients are set
        if (taxRecipients[keccak256("community")] == address(0) && communityAmount > 0) return false;
        if (taxRecipients[keccak256("team")] == address(0) && teamAmount > 0) return false;
        if (taxRecipients[keccak256("liquidity")] == address(0) && liquidityAmount > 0) return false;
        if (taxRecipients[keccak256("treasury")] == address(0) && treasuryAmount > 0) return false;
        if (taxRecipients[keccak256("marketing")] == address(0) && marketingAmount > 0) return false;
        if (taxRecipients[keccak256("cexLiquidity")] == address(0) && cexLiquidityAmount > 0) return false;

        // Validate total distribution matches tax amount
        return (communityAmount + teamAmount + liquidityAmount + treasuryAmount + 
                marketingAmount + cexLiquidityAmount) == taxAmount;
    }

    // Update tax distribution to use validation
    function _distributeTax(uint256 taxAmount) internal {
        require(_validateTaxDistribution(taxAmount), "Invalid tax distribution");
        uint256 communityAmount = (taxAmount * taxInfo.communityShare) / 100;
        uint256 teamAmount = (taxAmount * taxInfo.teamShare) / 100;
        uint256 liquidityAmount = (taxAmount * taxInfo.liquidityShare) / 100;
        uint256 treasuryAmount = (taxAmount * taxInfo.treasuryShare) / 100;
        uint256 marketingAmount = (taxAmount * taxInfo.marketingShare) / 100;
        uint256 cexLiquidityAmount = (taxAmount * taxInfo.cexLiquidityShare) / 100;

        _safeTransfer(address(this), taxRecipients[keccak256("community")], communityAmount);
        _safeTransfer(address(this), taxRecipients[keccak256("team")], teamAmount);
        _safeTransfer(address(this), taxRecipients[keccak256("liquidity")], liquidityAmount);
        _safeTransfer(address(this), taxRecipients[keccak256("treasury")], treasuryAmount);
        _safeTransfer(address(this), taxRecipients[keccak256("marketing")], marketingAmount);
        _safeTransfer(address(this), taxRecipients[keccak256("cexLiquidity")], cexLiquidityAmount);

        emit TaxDistributed(
            taxAmount,
            communityAmount,
            teamAmount,
            liquidityAmount,
            treasuryAmount,
            marketingAmount,
            cexLiquidityAmount
        );
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setMaxTransactionAmount(uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid amount");
        maxTransactionAmount = amount;
        emit MaxTransactionAmountUpdated(amount);
    }

    // Update transfer function checks
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        
        
        if (maxTransactionAmount > 0) {
            require(amount <= maxTransactionAmount, "Amount exceeds max transaction");
        }

        // Check max supply on mint
        if (from == address(0)) {
            require(totalSupply() + amount <= maxSupply, "Max supply exceeded");
        }
        super._update(from, to, amount);
    }

    // Update transfer functions to include pause check
    function transfer(address to, uint256 amount) 
        public 
        virtual 
        override(IERC20, ERC20)
        whenNotPaused 
        notBot(msg.sender, amount)
        rugProtected(msg.sender, amount)
        returns (bool)
    {
        uint256 taxAmount = calculateTax(amount);
        uint256 netAmount = amount - taxAmount;

        _transfer(msg.sender, address(this), taxAmount);
        _distributeTax(taxAmount);
        _transfer(msg.sender, to, netAmount);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override(IERC20, ERC20)
        whenNotPaused
        notBot(from, amount)
        rugProtected(from, amount)
        returns (bool)
    {
        uint256 taxAmount = calculateTax(amount);
        uint256 netAmount = amount - taxAmount;

        _spendAllowance(from, msg.sender, amount);
        _transfer(from, address(this), taxAmount);
        _distributeTax(taxAmount);
        _transfer(from, to, netAmount);

        return true;
    }

    /// @notice Transfers tokens from one address to another without tax handling
    /// @param from The sender address
    /// @param to The recipient address
    /// @param amount The amount to transfer
    /// @return success Whether the transfer was successful
    function factoryTransfer(address from, address to, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        require(msg.sender == address(factory), "Only factory can call");
        _transfer(from, to, amount);
        return true;
    }

    function queueOperation(bytes32 operationId) external onlyOwner {
        require(_timelockOperations[operationId].timestamp == 0, "Operation already queued");
        _timelockOperations[operationId] = TimelockOperation({
            operationId: operationId,
            timestamp: block.timestamp,
            executed: false
        });
        emit OperationQueued(operationId, block.timestamp + TIMELOCK_DELAY);
    }

    function _initializeTaxTypes() internal {
        _validTaxTypes[keccak256("community")] = true;
        _validTaxTypes[keccak256("team")] = true;
        _validTaxTypes[keccak256("liquidity")] = true;
        _validTaxTypes[keccak256("treasury")] = true;
        _validTaxTypes[keccak256("marketing")] = true;
        _validTaxTypes[keccak256("cexLiquidity")] = true;
    }

    function setTaxRecipient(string calldata taxType, address recipient) external onlyOwner {
        bytes32 taxTypeHash = keccak256(bytes(taxType));
        require(_validTaxTypes[taxTypeHash], "Invalid tax type");
        require(recipient != address(0), "Invalid recipient");
        
        // Check if previous recipient exists
        address previousRecipient = taxRecipients[taxTypeHash];
        if (previousRecipient != address(0)) {
            _usedTaxRecipients[previousRecipient] = false;
            _totalTaxRecipients--;
        }

        // Validate new recipient
        if (!_usedTaxRecipients[recipient]) {
            require(_totalTaxRecipients < MAX_TAX_RECIPIENTS, "Too many recipients");
            _usedTaxRecipients[recipient] = true;
            _totalTaxRecipients++;
        }
        
        taxRecipients[taxTypeHash] = recipient;
        emit TaxRecipientUpdated(taxType, recipient);
    }

    function addTaxType(string calldata taxType) external onlyOwner {
        bytes32 taxTypeHash = keccak256(bytes(taxType));
        require(!_validTaxTypes[taxTypeHash], "Tax type exists");
        
        _validTaxTypes[taxTypeHash] = true;
        emit TaxTypeAdded(taxType);
    }

    function removeTaxType(string calldata taxType) external onlyOwner {
        bytes32 taxTypeHash = keccak256(bytes(taxType));
        require(_validTaxTypes[taxTypeHash], "Invalid tax type");
        
        address recipient = taxRecipients[taxTypeHash];
        require(recipient == address(0), "Remove recipient first");
        
        _validTaxTypes[taxTypeHash] = false;
        emit TaxTypeRemoved(taxType);
    }

    function clearTaxRecipient(string calldata taxType) external onlyOwner {
        bytes32 taxTypeHash = keccak256(bytes(taxType));
        require(_validTaxTypes[taxTypeHash], "Invalid tax type");
        
        address recipient = taxRecipients[taxTypeHash];
        if (recipient != address(0)) {
            _usedTaxRecipients[recipient] = false;
            _totalTaxRecipients--;
            taxRecipients[taxTypeHash] = address(0);
            emit TaxRecipientUpdated(taxType, address(0));
        }
    }

    // Add explicit override for owner()
    function owner() public view virtual override(Ownable, IUserToken) returns (address) {
        return super.owner();
    }
} 