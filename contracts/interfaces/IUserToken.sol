// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUserToken is IERC20 {
    struct TaxInfo {
        uint256 communityShare;
        uint256 teamShare;
        uint256 liquidityShare;
        uint256 treasuryShare;
        uint256 marketingShare;
        uint256 cexLiquidityShare;
    }

    event TaxDistributed(
        uint256 amount,
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 liquidityAmount,
        uint256 treasuryAmount,
        uint256 marketingAmount,
        uint256 cexLiquidityAmount
    );

    event AntiRugLockUpdated(bool locked);
    event AntiBotProtectionUpdated(bool enabled);

    /// @notice Gets the owner of the token
    /// @return The owner address
    function owner() external view returns (address);

    /// @notice Initializes the token with its basic parameters
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param owner The owner of the token
    /// @param creationFee The fee for creating the token
    /// @param tokenomics The tokenomics contract address
    /// @param WETH The WETH contract address
    function initialize(
        string memory name,
        string memory symbol,
        address owner,
        uint256 creationFee,
        address tokenomics,
        address WETH
    ) external;

    /// @notice Configures the token's wallet addresses
    /// @param communityWallet The community wallet address
    /// @param teamWallet The team wallet address
    /// @param dexLiquidityWallet The DEX liquidity wallet address
    /// @param treasuryWallet The treasury wallet address
    /// @param marketingWallet The marketing wallet address
    /// @param cexLiquidityWallet The CEX liquidity wallet address
    function configure(
        address communityWallet,
        address teamWallet,
        address dexLiquidityWallet,
        address treasuryWallet,
        address marketingWallet,
        address cexLiquidityWallet
    ) external;

    /// @notice Configures the token's parameters
    /// @param maxSupply The maximum supply of the token
    /// @param transferDelay The transfer delay period
    /// @param maxTxAmount The maximum transaction amount
    /// @param maxWalletAmount The maximum wallet amount
    function configure(
        uint256 maxSupply,
        uint256 transferDelay,
        uint256 maxTxAmount,
        uint256 maxWalletAmount
    ) external;

    /// @notice Sets the pool controller address
    /// @param _poolController The new pool controller address
    function setPoolController(address _poolController) external;

    /// @notice Mints new tokens
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice Burns tokens from an address
    /// @param from The address to burn tokens from
    /// @param amount The amount of tokens to burn
    function burn(address from, uint256 amount) external;

    /// @notice Gets the current price of the token
    /// @return price The current token price
    function getCurrentPrice() external view returns (uint256 price);

    /// @notice Gets the pool address for the token
    /// @return pool The pool address
    function getPoolAddress() external view returns (address pool);

    /// @notice Gets the tax information for the token
    /// @return info The tax information struct
    function getTaxInfo() external view returns (TaxInfo memory info);

    /// @notice Gets the tax recipient addresses
    /// @return communityWallet The community wallet address
    /// @return teamWallet The team wallet address
    /// @return treasuryWallet The treasury wallet address
    /// @return marketingWallet The marketing wallet address
    /// @return cexLiquidityWallet The CEX liquidity wallet address
    function getTaxRecipients() external view returns (
        address communityWallet,
        address teamWallet,
        address treasuryWallet,
        address marketingWallet,
        address cexLiquidityWallet
    );

    /// @notice Gets the metadata URI for the token
    /// @return uri The metadata URI
    function metadataURI() external view returns (string memory uri);

    /// @notice Checks if anti-bot protection is enabled
    /// @return enabled Whether anti-bot protection is enabled
    function isAntiBotEnabled() external view returns (bool enabled);

    /// @notice Checks if anti-rug lock is enabled
    /// @return locked Whether anti-rug lock is enabled
    function isAntiRugLocked() external view returns (bool locked);

    /// @notice Gets the liquidity provider address
    /// @return liquidityProvider The liquidity provider address
    function getLiquidityProvider() external view returns (address liquidityProvider);

    /// @notice Sets the liquidity provider address
    /// @param liquidityProvider The new liquidity provider address
    function setLiquidityProvider(address liquidityProvider) external;

    /// @notice Sets the anti-bot protection status
    /// @param enabled The new anti-bot protection status
    function setAntiBotProtection(bool enabled) external;

    /// @notice Sets the anti-rug lock status
    /// @param locked The new anti-rug lock status
    function setAntiRugLock(bool locked) external;

    /// @notice Transfers tokens from one address to another without tax handling
    /// @param from The sender address
    /// @param to The recipient address
    /// @param amount The amount to transfer
    /// @return success Whether the transfer was successful
    function factoryTransfer(address from, address to, uint256 amount) external returns (bool success);
}