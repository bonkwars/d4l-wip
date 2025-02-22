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

interface ITokenFactory {
    struct TokenCreationParams {
        string name;
        string symbol;
        uint8 decimals;
        uint256 initialSupply;
        uint256 maxSupply;
        uint256 creationFee;
        bytes signature;
        string metadata;
        uint256 initialLiquidityAmount;
    }

    struct TokenConfig {
        uint128 maxSupply;    // Pack into single slot
        uint64 maxTxAmount;
        uint64 maxWalletAmount;
        bool mintable;
        bool burnable;
        bool pausable;
        uint256 transferDelay;
        address feeRecipient;
        uint16 buyFee;
        uint16 sellFee;
        uint16 transferFee;
    }

    event TokenCreated(address indexed token, address indexed creator, string name, string symbol, uint256 initialSupply);
    event TokenConfigured(address indexed token, address indexed owner, TokenConfig config);

    function createToken(string memory name, string memory symbol, uint256 initialSupply) external returns (address);
    function createToken(TokenCreationParams calldata params) external payable returns (address);
    function createToken(string memory name, string memory symbol, uint256 initialSupply, address creator, uint256 initialLiquidity) external returns (address);
    function updateTokenConfig(address token, TokenConfig calldata newConfig) external;
    function setTokenImplementation(address implementation) external;
    function setPoolController(address controller) external;
    function getCreationFee() external view returns (uint256);
    function verifyFalconSignature(address creator, bytes memory signature) external view returns (bool);
    function isFactoryToken(address token) external view returns (bool);
    function isD4LToken(address token) external view returns (bool);
    function setCreationFee(uint256 newFee) external;
    function setController(address controller) external;
    function getAllTokens() external view returns (address[] memory);
    function getTaxConfiguration() external view returns (
        uint256 communityShare,
        uint256 teamShare,
        uint256 liquidityShare,
        uint256 treasuryShare,
        uint256 marketingShare,
        uint256 cexLiquidityShare
    );
}