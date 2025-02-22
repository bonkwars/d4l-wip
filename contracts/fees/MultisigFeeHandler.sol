// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ITokenomics.sol";
import "../constants/constants.sol";

/**
 * @title MultisigFeeHandler
 * @notice Handles fee collection and distribution to the central Treasury Multisig
 */
contract MultisigFeeHandler is Ownable, ReentrancyGuard {
    // Constants
    uint256 public constant CREATION_FEE_PERCENTAGE = 3; // 3% of gas cost
    
    // Chain-specific treasury addresses
    mapping(uint256 => address) public chainTreasury;
    
    // Interfaces
    ITokenomics public immutable tokenomics;
    
    // Events
    event FeesDistributed(
        address indexed token,
        uint256 amount,
        address indexed treasury
    );
    
    event TreasuryUpdated(uint256 indexed chainId, address treasury);
    event TokenCreationFeeProcessed(
        address indexed creator,
        uint256 gasCost,
        uint256 feeAmount
    );

    constructor(address _tokenomics) Ownable(msg.sender) {
        tokenomics = ITokenomics(_tokenomics);
        _initializeTreasury();
    }

    /**
     * @notice Calculates the token creation fee based on gas cost
     * @param gasUsed Amount of gas used for token creation
     * @param gasPrice Price of gas in wei
     * @return fee The calculated fee amount
     */
    function calculateCreationFee(
        uint256 gasUsed,
        uint256 gasPrice
    ) public pure returns (uint256) {
        uint256 gasCost = gasUsed * gasPrice;
        return (gasCost * CREATION_FEE_PERCENTAGE) / 100;
    }

    /**
     * @notice Processes the token creation fee
     * @param gasUsed Amount of gas used for token creation
     */
    function processTokenCreationFee(
        uint256 gasUsed
    ) external payable nonReentrant {
        uint256 feeAmount = calculateCreationFee(gasUsed, tx.gasprice);
        require(msg.value == feeAmount, "Invalid fee amount");
        
        distributeFees(address(0), feeAmount);
        emit TokenCreationFeeProcessed(msg.sender, gasUsed * tx.gasprice, feeAmount);
    }

    /**
     * @notice Distributes fees to the treasury
     * @param token The token address (address(0) for ETH)
     * @param amount The amount to distribute
     */
    function distributeFees(
        address token,
        uint256 amount
    ) public payable nonReentrant {
        require(amount > 0, "Zero amount");
        
        // Get current chain's treasury
        address treasury = chainTreasury[block.chainid];
        require(treasury != address(0), "Chain not configured");

        // Handle ETH distribution
        if (token == address(0)) {
            require(msg.value == amount, "Invalid ETH amount");
            (bool success, ) = treasury.call{value: amount}("");
            require(success, "ETH transfer failed");
        }
        // Handle ERC20 distribution
        else {
            require(IERC20(token).transferFrom(msg.sender, treasury, amount), "Transfer failed");
        }

        emit FeesDistributed(token, amount, treasury);
    }

    /**
     * @notice Updates treasury address for a specific chain
     */
    function updateChainTreasury(
        uint256 chainId,
        address newTreasury
    ) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        chainTreasury[chainId] = newTreasury;
        emit TreasuryUpdated(chainId, newTreasury);
    }

    /**
     * @notice Initializes treasury addresses for all supported chains
     */
    function _initializeTreasury() internal {
        // Base Sepolia
        chainTreasury[CHAIN_ID_BASE_SEPOLIA] = BASE_SEPOLIA_MULTISIG_SAFE;
        
        // ETH Sepolia
        chainTreasury[CHAIN_ID_ETH_SEPOLIA] = ETH_SEPOLIA_MULTISIG_SAFE;
        
        // Polygon Sepolia
        chainTreasury[CHAIN_ID_POLYGON_SEPOLIA] = POLYGON_SEPOLIA_MULTISIG_SAFE;
        
        // Arbitrum Sepolia
        chainTreasury[CHAIN_ID_ARBITRUM_SEPOLIA] = ARBITRUM_SEPOLIA_MULTISIG_SAFE;
    }

    receive() external payable {}
} 