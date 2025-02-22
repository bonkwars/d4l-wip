// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../interfaces/IContractRegistry.sol";
import "../interfaces/ITokenomics.sol";
import "../interfaces/IMultiChainToken.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title D4LToken
 * @notice Native token of the Degen4Life platform with special features
 * @dev Implements DAO governance, platform-specific tokenomics, and cross-chain functionality
 */
contract D4LToken is 
    ERC20VotesUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable,
    ERC165Upgradeable,
    OwnableUpgradeable,
    IMultiChainToken
{
    // Constants
    uint256 internal immutable INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1 billion tokens
    uint256 internal immutable MAX_SUPPLY = 1_000_000_000 * 1e18;     // Fixed max supply
    uint256 internal immutable VESTING_DURATION = 365 days;           // 1 year vesting
    uint256 internal immutable CLIFF_DURATION = 90 days;              // 3 months cliff
    uint256 internal immutable RELEASE_INTERVAL = 1 days;             // Daily release
    
    // Allocation percentages (in basis points, 100 = 1%)
    uint256 internal immutable TEAM_ALLOCATION = 1500;        // 15%
    uint256 internal immutable ADVISORS_ALLOCATION = 500;     // 5%
    uint256 internal immutable ECOSYSTEM_ALLOCATION = 2000;   // 20%
    uint256 internal immutable LIQUIDITY_ALLOCATION = 1500;   // 15%
    uint256 internal immutable COMMUNITY_ALLOCATION = 4500;   // 45%

    // Bridge constants
    bytes32 internal immutable DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 internal immutable BRIDGE_TYPEHASH = keccak256(
        "Bridge(address to,uint256 amount,uint256 nonce,uint256 targetChainId)"
    );

    // Bridge variables
    bytes32 private DOMAIN_SEPARATOR;
    mapping(address => bool) private _bridgeAddresses;
    mapping(uint256 => bool) private _processedNonces;
    uint256 private _chainId;

    // Meta-transaction variables
    address private _trustedForwarder;

    // ERC-7579 variables
    mapping(address => mapping(uint256 => bool)) private _isSafe;
    mapping(address => mapping(uint256 => mapping(bytes4 => bool))) private _restrictedFunctions;

    // State variables
    IContractRegistry public registry;
    ITokenomics public tokenomics;
    address public governanceAddress;
    
    // Vesting schedule
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffEnd;
        uint256 endTime;
        uint256 lastClaimTime;
        uint256 claimedAmount;
        bool revocable;
        bool revoked;
    }
    
    // Mappings for vesting and staking
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakingStartTime;
    mapping(address => uint256) public rewardDebt;

    // Events for token functionality (not from IMultiChainToken)
    event TokensVested(address indexed beneficiary, uint256 amount);
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount);
    event VestingScheduleRevoked(address indexed beneficiary);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    // Getters for constants
    function getInitialSupply() public pure returns (uint256) { return INITIAL_SUPPLY; }
    function getMaxSupply() public pure returns (uint256) { return MAX_SUPPLY; }
    function getVestingDuration() public pure returns (uint256) { return VESTING_DURATION; }
    function getCliffDuration() public pure returns (uint256) { return CLIFF_DURATION; }
    function getReleaseInterval() public pure returns (uint256) { return RELEASE_INTERVAL; }
    function getTeamAllocation() public pure returns (uint256) { return TEAM_ALLOCATION; }
    function getAdvisorsAllocation() public pure returns (uint256) { return ADVISORS_ALLOCATION; }
    function getEcosystemAllocation() public pure returns (uint256) { return ECOSYSTEM_ALLOCATION; }
    function getLiquidityAllocation() public pure returns (uint256) { return LIQUIDITY_ALLOCATION; }
    function getCommunityAllocation() public pure returns (uint256) { return COMMUNITY_ALLOCATION; }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _registry,
        address _tokenomics,
        address _governanceAddress,
        address teamWallet,
        address advisorsWallet,
        address ecosystemWallet,
        address liquidityWallet,
        address communityWallet,
        address _forwarder
    ) external initializer {
        // Initialize base contracts
        __Context_init();
        __ERC20_init("Degen4Life", "D4L");
        __ERC20Votes_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __ERC165_init();
        __Ownable_init(_msgSender());
        __EIP712_init("Degen4Life", "1");
        
        // Set trusted forwarder
        _trustedForwarder = _forwarder;
        
        registry = IContractRegistry(_registry);
        tokenomics = ITokenomics(_tokenomics);
        governanceAddress = _governanceAddress;
        _chainId = block.chainid;
        
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes("Degen4Life")),
                keccak256(bytes("1")),
                _chainId,
                address(this)
            )
        );
        
        // Create initial supply
        _mint(address(this), INITIAL_SUPPLY);
        
        // Create vesting schedules
        _createVestingSchedule(teamWallet, (INITIAL_SUPPLY * TEAM_ALLOCATION) / 10000, true);
        _createVestingSchedule(advisorsWallet, (INITIAL_SUPPLY * ADVISORS_ALLOCATION) / 10000, true);
        _createVestingSchedule(ecosystemWallet, (INITIAL_SUPPLY * ECOSYSTEM_ALLOCATION) / 10000, false);
        
        // Transfer liquidity and community allocations immediately
        _transfer(address(this), liquidityWallet, (INITIAL_SUPPLY * LIQUIDITY_ALLOCATION) / 10000);
        _transfer(address(this), communityWallet, (INITIAL_SUPPLY * COMMUNITY_ALLOCATION) / 10000);
    }

    function trustedForwarder() public view returns (address) {
        return _trustedForwarder;
    }

    function isTrustedForwarder(address _forwarder) public view returns (bool) {
        return _forwarder == _trustedForwarder;
    }

    function _msgSender() internal view virtual override returns (address) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is equivalent to:
            // return address(bytes20(msg.data[msg.data.length - 20:])))
            assembly {
                let sender := shr(96, calldataload(sub(calldatasize(), 20)))
                mstore(0x00, sender)
                return(0x00, 32)
            }
        }
        return super._msgSender();
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        }
        return super._msgData();
    }

    // Vesting functions
    function _createVestingSchedule(
        address beneficiary,
        uint256 amount,
        bool revocable
    ) internal {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be > 0");
        
        uint256 start = block.timestamp;
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            startTime: start,
            cliffEnd: start + CLIFF_DURATION,
            endTime: start + VESTING_DURATION,
            lastClaimTime: start,
            claimedAmount: 0,
            revocable: revocable,
            revoked: false
        });
        
        emit VestingScheduleCreated(beneficiary, amount);
    }
    
    function claimVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(!schedule.revoked, "Schedule revoked");
        require(block.timestamp > schedule.cliffEnd, "Cliff not ended");
        
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        require(vestedAmount > schedule.claimedAmount, "No tokens to claim");
        
        uint256 claimableAmount = vestedAmount - schedule.claimedAmount;
        schedule.claimedAmount = vestedAmount;
        schedule.lastClaimTime = block.timestamp;
        
        _transfer(address(this), msg.sender, claimableAmount);
        emit TokensVested(msg.sender, claimableAmount);
    }
    
    function _calculateVestedAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.cliffEnd) return 0;
        if (block.timestamp >= schedule.endTime) return schedule.totalAmount;
        
        uint256 timeFromStart = block.timestamp - schedule.cliffEnd;
        uint256 vestingTime = schedule.endTime - schedule.cliffEnd;
        
        return (schedule.totalAmount * timeFromStart) / vestingTime;
    }
    
    // Staking functions
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Harvest any pending rewards first
        _harvestRewards(msg.sender);
        
        // Update staking info
        stakedBalance[msg.sender] += amount;
        stakingStartTime[msg.sender] = block.timestamp;
        
        // Transfer tokens to contract
        _transfer(msg.sender, address(this), amount);
        
        emit Staked(msg.sender, amount);
    }
    
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");
        
        // Harvest any pending rewards first
        _harvestRewards(msg.sender);
        
        // Update staking info
        stakedBalance[msg.sender] -= amount;
        
        // Transfer tokens back to user
        _transfer(address(this), msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    function _harvestRewards(address user) internal {
        uint256 pending = pendingRewards(user);
        if (pending > 0) {
            rewardDebt[user] = block.timestamp;
            _mint(user, pending); // Mint new tokens as rewards, up to MAX_SUPPLY
            emit RewardPaid(user, pending);
        }
    }
    
    function pendingRewards(address user) public view returns (uint256) {
        if (stakedBalance[user] == 0) return 0;
        
        uint256 timeStaked = block.timestamp - stakingStartTime[user];
        uint256 baseReward = (stakedBalance[user] * timeStaked * 15) / (365 days * 100); // 15% APY
        
        // Apply multiplier based on amount staked
        uint256 multiplier = _calculateMultiplier(stakedBalance[user]);
        return (baseReward * multiplier) / 100;
    }
    
    function _calculateMultiplier(uint256 amount) internal pure returns (uint256) {
        // Tier 1: < 10,000 D4L = 100% (base)
        if (amount < 10_000 * 1e18) return 100;
        // Tier 2: 10,000-50,000 D4L = 125%
        if (amount < 50_000 * 1e18) return 125;
        // Tier 3: 50,000-100,000 D4L = 150%
        if (amount < 100_000 * 1e18) return 150;
        // Tier 4: > 100,000 D4L = 200%
        return 200;
    }
    
    // Override transfer functions to handle fees and restrictions
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20VotesUpgradeable) {
        // Check max supply on mint
        if (from == address(0)) {
            require(totalSupply() + value <= MAX_SUPPLY, "D4L: Max supply exceeded");
        }

        // Check if transfer is restricted for any involved safes
        bytes4 transferSig = bytes4(keccak256("transfer(address,uint256)"));
        require(
            !_restrictedFunctions[from][0][transferSig] && // Check sender's restrictions
            !_restrictedFunctions[to][0][transferSig],     // Check recipient's restrictions
            "Transfer restricted by safe"
        );

        if (from != governanceAddress && to != governanceAddress) {
            require(!paused(), "Transfers paused");
        }
        
        // Calculate and apply fees if needed
        uint256 fee = _calculateFee(from, to, value);
        uint256 netValue = value - fee;
        
        if (fee > 0) {
            super._update(from, address(this), fee);
            tokenomics.distributeFees(fee);
        }
        
        super._update(from, to, netValue);
    }

    function _calculateFee(
        address from,
        address to,
        uint256 amount
    ) internal view returns (uint256) {
        if (from == governanceAddress || to == governanceAddress) return 0;
        if (from == address(this) || to == address(this)) return 0;
        return tokenomics.calculateTotalFees(amount);
    }

    // Bridge functions
    function getDomainSeparator() public view returns (bytes32) {
        return DOMAIN_SEPARATOR;
    }

    // IMultiChainToken interface implementation
    function bridgeAddresses(address bridge) external view override returns (bool) {
        return _bridgeAddresses[bridge];
    }

    function processedNonces(uint256 nonce) external view override returns (bool) {
        return _processedNonces[nonce];
    }

    function chainId() external view override returns (uint256) {
        return _chainId;
    }

    function addBridge(address bridge) external override onlyOwner {
        _bridgeAddresses[bridge] = true;
    }

    function removeBridge(address bridge) external override onlyOwner {
        _bridgeAddresses[bridge] = false;
    }

    function bridgeTokens(
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 targetChainId
    ) external override nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(targetChainId != _chainId, "Cannot bridge to same chain");
        require(!_processedNonces[nonce], "Nonce already processed");
        
        _processedNonces[nonce] = true;
        _burn(_msgSender(), amount);
        
        emit TokensBridged(
            _msgSender(),
            to,
            amount,
            nonce,
            _chainId,
            targetChainId
        );
    }

    function mintBridgedTokens(
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 fromChainId
    ) external override nonReentrant whenNotPaused {
        require(_bridgeAddresses[_msgSender()], "Not authorized bridge");
        require(!_processedNonces[nonce], "Nonce already processed");
        require(fromChainId != _chainId, "Invalid source chain");
        
        _processedNonces[nonce] = true;
        _mint(to, amount);
    }

    function setSafe(uint256 tokenId, bool safe) external override {
        require(msg.sender == owner() || _isSafe[msg.sender][tokenId], "Not authorized");
        _isSafe[msg.sender][tokenId] = safe;
        emit SafeUpdated(msg.sender, tokenId, safe);
    }

    function isSafe(address _account, uint256 tokenId) public view override returns (bool) {
        return _isSafe[_account][tokenId];
    }
    
    function setFunctionRestriction(
        uint256 tokenId,
        bytes4 functionSig,
        bool restricted
    ) external override {
        require(_isSafe[msg.sender][tokenId], "Not a safe");
        _restrictedFunctions[msg.sender][tokenId][functionSig] = restricted;
        emit FunctionRestrictionUpdated(msg.sender, tokenId, functionSig, restricted);
    }

    function isFunctionRestricted(
        address _account,
        uint256 tokenId,
        bytes4 functionSig
    ) public view override returns (bool) {
        return _restrictedFunctions[_account][tokenId][functionSig];
    }

    function owner() public view virtual override(OwnableUpgradeable) returns (address) {
        return OwnableUpgradeable.owner();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165) returns (bool) {
        return
            interfaceId == type(IMultiChainToken).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(!schedule.revoked, "Already revoked");
        require(schedule.revocable, "Schedule not revocable");

        schedule.revoked = true;
        emit VestingScheduleRevoked(beneficiary);
    }
} 