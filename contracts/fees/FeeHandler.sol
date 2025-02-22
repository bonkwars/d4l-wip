// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "../constants/constants.sol";

/**
 * @title FeeHandler
 * @notice Handles base fees and tax distribution for token creation and trading
 */
contract FeeHandler is Owned {
    using SafeTransferLib for address;

    // Events
    event FeeCollected(address indexed token, uint256 amount, string feeType);
    event TaxDistributed(
        address indexed token,
        uint256 amount,
        uint256 communityShare,
        uint256 teamShare,
        uint256 liquidityShare,
        uint256 treasuryShare,
        uint256 marketingShare,
        uint256 cexLiquidityShare
    );

    // Constants from tokenomics
    uint256 constant COMMUNITY_SHARE = 25;
    uint256 constant TEAM_SHARE = 20;
    uint256 constant LIQUIDITY_SHARE = 30;
    uint256 constant TREASURY_SHARE = 10;
    uint256 constant MARKETING_SHARE = 10;
    uint256 constant CEX_LIQUIDITY_SHARE = 5;

    // Wallet addresses
    address public communityWallet;
    address public teamWallet;
    address public treasuryWallet;
    address public marketingWallet;
    address public cexLiquidityWallet;

    constructor(
        address _communityWallet,
        address _teamWallet,
        address _treasuryWallet,
        address _marketingWallet,
        address _cexLiquidityWallet
    ) Owned(msg.sender) {
        communityWallet = _communityWallet;
        teamWallet = _teamWallet;
        treasuryWallet = _treasuryWallet;
        marketingWallet = _marketingWallet;
        cexLiquidityWallet = _cexLiquidityWallet;
    }

    /**
     * @notice Collects the base fee for token creation
     * @dev Must be called with exactly BASE_FEE value
     */
    function collectBaseFee() external payable {
        require(msg.value == BASE_FEE, "Invalid fee amount");
        emit FeeCollected(address(0), msg.value, "base");
    }

    /**
     * @notice Distributes transaction tax according to tokenomics
     * @param token The token address
     */
    function distributeTax(address token) external payable {
        require(msg.value > 0, "No tax to distribute");

        uint256 communityAmount = (msg.value * COMMUNITY_SHARE) / 100;
        uint256 teamAmount = (msg.value * TEAM_SHARE) / 100;
        uint256 liquidityAmount = (msg.value * LIQUIDITY_SHARE) / 100;
        uint256 treasuryAmount = (msg.value * TREASURY_SHARE) / 100;
        uint256 marketingAmount = (msg.value * MARKETING_SHARE) / 100;
        uint256 cexLiquidityAmount = (msg.value * CEX_LIQUIDITY_SHARE) / 100;

        // Transfer shares to respective wallets
        communityWallet.safeTransferETH(communityAmount);
        teamWallet.safeTransferETH(teamAmount);
        treasuryWallet.safeTransferETH(treasuryAmount);
        marketingWallet.safeTransferETH(marketingAmount);
        cexLiquidityWallet.safeTransferETH(cexLiquidityAmount);

        // Handle liquidity share separately (can be used for auto-LP)
        _handleLiquidityShare(token, liquidityAmount);

        emit TaxDistributed(
            token,
            msg.value,
            communityAmount,
            teamAmount,
            liquidityAmount,
            treasuryAmount,
            marketingAmount,
            cexLiquidityAmount
        );
    }

    /**
     * @notice Updates wallet addresses
     */
    function updateWallets(
        address _communityWallet,
        address _teamWallet,
        address _treasuryWallet,
        address _marketingWallet,
        address _cexLiquidityWallet
    ) external onlyOwner {
        require(_communityWallet != address(0), "Invalid community wallet");
        require(_teamWallet != address(0), "Invalid team wallet");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        require(_marketingWallet != address(0), "Invalid marketing wallet");
        require(_cexLiquidityWallet != address(0), "Invalid CEX liquidity wallet");

        communityWallet = _communityWallet;
        teamWallet = _teamWallet;
        treasuryWallet = _treasuryWallet;
        marketingWallet = _marketingWallet;
        cexLiquidityWallet = _cexLiquidityWallet;
    }

    /**
     * @notice Handles the liquidity share of the tax
     * @dev Can be extended to automatically add liquidity
     */
    function _handleLiquidityShare(address token, uint256 amount) internal {
        // For now, just transfer to treasury
        // This can be extended to automatically add liquidity
        treasuryWallet.safeTransferETH(amount);
    }
} 