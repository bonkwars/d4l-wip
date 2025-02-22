// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/ITokenomics.sol";

/**
 * @title MarketingPool
 * @notice Manages marketing funds with campaign tracking and ROI-based distribution
 */
contract MarketingPool is Ownable, ReentrancyGuard, Pausable {
    // Structs
    struct Campaign {
        string name;
        uint256 budget;
        uint256 spent;
        uint256 startTime;
        uint256 endTime;
        uint256 targetROI;
        uint256 actualROI;
        bool isActive;
        address[] vendors;
        mapping(address => uint256) vendorAllocations;
        mapping(address => uint256) vendorSpent;
    }

    struct Vendor {
        string name;
        address paymentAddress;
        uint256 totalAllocated;
        uint256 totalSpent;
        uint256 averageROI;
        bool isActive;
        uint256[] campaignIds;
    }

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_CAMPAIGN_DURATION = 7 days;
    uint256 public constant MAX_CAMPAIGN_DURATION = 365 days;
    uint256 public constant MAX_VENDOR_ALLOCATION = 5000; // 50% of total budget
    uint256 public constant PERFORMANCE_THRESHOLD = 8000; // 80% of target ROI

    // State variables
    mapping(uint256 => Campaign) public campaigns;
    mapping(address => Vendor) public vendors;
    uint256 public nextCampaignId;
    uint256 public totalCampaigns;
    uint256 public totalVendors;
    uint256 public totalBudget;
    uint256 public totalSpent;

    address public immutable distributor;
    IERC20 public immutable rewardToken;

    // Events
    event CampaignCreated(uint256 indexed campaignId, string name, uint256 budget);
    event CampaignUpdated(uint256 indexed campaignId, uint256 actualROI);
    event CampaignClosed(uint256 indexed campaignId, bool success);
    event VendorAdded(address indexed vendor, string name);
    event VendorAllocationUpdated(uint256 indexed campaignId, address indexed vendor, uint256 amount);
    event VendorPayment(address indexed vendor, uint256 amount);
    event ROIUpdated(uint256 indexed campaignId, uint256 oldROI, uint256 newROI);
    event EmergencyWithdrawn(address indexed token, uint256 amount, address recipient);

    // Modifiers
    modifier onlyDistributor() {
        require(msg.sender == distributor, "Only distributor");
        _;
    }

    modifier campaignExists(uint256 campaignId) {
        require(campaignId < nextCampaignId, "Campaign not found");
        require(campaigns[campaignId].isActive, "Campaign not active");
        _;
    }

    modifier vendorExists(address vendor) {
        require(vendors[vendor].isActive, "Vendor not found");
        _;
    }

    constructor(
        address _distributor,
        address _rewardToken
    ) Ownable(msg.sender) {
        require(_distributor != address(0), "Invalid distributor");
        require(_rewardToken != address(0), "Invalid reward token");
        distributor = _distributor;
        rewardToken = IERC20(_rewardToken);
    }

    /**
     * @notice Creates a new marketing campaign
     */
    function createCampaign(
        string calldata name,
        uint256 budget,
        uint256 startTime,
        uint256 endTime,
        uint256 targetROI
    ) external onlyOwner {
        require(bytes(name).length > 0, "Empty name");
        require(budget > 0, "Zero budget");
        require(startTime >= block.timestamp, "Invalid start time");
        require(endTime > startTime, "Invalid end time");
        require(
            endTime - startTime >= MIN_CAMPAIGN_DURATION &&
            endTime - startTime <= MAX_CAMPAIGN_DURATION,
            "Invalid duration"
        );

        uint256 campaignId = nextCampaignId++;
        Campaign storage campaign = campaigns[campaignId];
        campaign.name = name;
        campaign.budget = budget;
        campaign.startTime = startTime;
        campaign.endTime = endTime;
        campaign.targetROI = targetROI;
        campaign.isActive = true;

        totalCampaigns++;
        totalBudget += budget;

        emit CampaignCreated(campaignId, name, budget);
    }

    /**
     * @notice Adds a new vendor
     */
    function addVendor(
        address vendorAddress,
        string calldata name
    ) external onlyOwner {
        require(vendorAddress != address(0), "Invalid address");
        require(bytes(name).length > 0, "Empty name");
        require(!vendors[vendorAddress].isActive, "Vendor exists");

        vendors[vendorAddress] = Vendor({
            name: name,
            paymentAddress: vendorAddress,
            totalAllocated: 0,
            totalSpent: 0,
            averageROI: 0,
            isActive: true,
            campaignIds: new uint256[](0)
        });

        totalVendors++;
        emit VendorAdded(vendorAddress, name);
    }

    /**
     * @notice Allocates budget to a vendor for a campaign
     */
    function allocateToVendor(
        uint256 campaignId,
        address vendor,
        uint256 amount
    ) external onlyOwner campaignExists(campaignId) vendorExists(vendor) {
        Campaign storage campaign = campaigns[campaignId];
        require(amount <= campaign.budget * MAX_VENDOR_ALLOCATION / BASIS_POINTS, "Exceeds max allocation");
        require(campaign.vendorAllocations[vendor] == 0, "Already allocated");

        campaign.vendorAllocations[vendor] = amount;
        campaign.vendors.push(vendor);
        vendors[vendor].campaignIds.push(campaignId);
        vendors[vendor].totalAllocated += amount;

        emit VendorAllocationUpdated(campaignId, vendor, amount);
    }

    /**
     * @notice Processes payment to a vendor
     */
    function processVendorPayment(
        uint256 campaignId,
        address vendor,
        uint256 amount
    ) external onlyOwner campaignExists(campaignId) vendorExists(vendor) {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.vendorAllocations[vendor] >= 
            campaign.vendorSpent[vendor] + amount, "Exceeds allocation");

        campaign.spent += amount;
        campaign.vendorSpent[vendor] += amount;
        vendors[vendor].totalSpent += amount;
        totalSpent += amount;

        require(rewardToken.transfer(vendors[vendor].paymentAddress, amount), "Transfer failed");
        emit VendorPayment(vendor, amount);
    }

    /**
     * @notice Updates campaign ROI
     */
    function updateCampaignROI(
        uint256 campaignId,
        uint256 newROI
    ) external onlyOwner campaignExists(campaignId) {
        Campaign storage campaign = campaigns[campaignId];
        uint256 oldROI = campaign.actualROI;
        campaign.actualROI = newROI;

        // Update vendor average ROI
        for (uint256 i = 0; i < campaign.vendors.length; i++) {
            address vendor = campaign.vendors[i];
            if (campaign.vendorSpent[vendor] > 0) {
                Vendor storage v = vendors[vendor];
                uint256 campaignCount = v.campaignIds.length;
                v.averageROI = (v.averageROI * (campaignCount - 1) + newROI) / campaignCount;
            }
        }

        emit ROIUpdated(campaignId, oldROI, newROI);
    }

    /**
     * @notice Closes a campaign
     */
    function closeCampaign(uint256 campaignId) external onlyOwner campaignExists(campaignId) {
        Campaign storage campaign = campaigns[campaignId];
        require(block.timestamp >= campaign.endTime, "Campaign active");

        bool success = campaign.actualROI >= campaign.targetROI * PERFORMANCE_THRESHOLD / BASIS_POINTS;
        campaign.isActive = false;

        emit CampaignClosed(campaignId, success);
    }

    /**
     * @notice Distributes new funds from the automated distributor
     */
    function distributeRewards() external payable onlyDistributor nonReentrant whenNotPaused {
        require(msg.value > 0, "Zero value");
        totalBudget += msg.value;
    }

    /**
     * @notice Emergency withdrawal of stuck funds
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        
        if (token == address(0)) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            require(IERC20(token).transfer(recipient, amount), "Token transfer failed");
        }

        emit EmergencyWithdrawn(token, amount, recipient);
    }

    /**
     * @notice Pauses all non-essential functions
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses all functions
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {
        require(msg.sender == distributor, "Only distributor");
    }
} 