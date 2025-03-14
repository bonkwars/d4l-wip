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

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IMultiChainToken is IERC165 {
    event TokensBridged(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 nonce,
        uint256 fromChainId,
        uint256 toChainId
    );

    event SafeUpdated(address indexed owner, uint256 indexed tokenId, bool isSafe);
    event FunctionRestrictionUpdated(
        address indexed owner, 
        uint256 indexed tokenId, 
        bytes4 indexed functionSig,
        bool isRestricted
    );

    function bridgeAddresses(address) external view returns (bool);
    function processedNonces(uint256) external view returns (bool);
    function chainId() external view returns (uint256);
    
    function addBridge(address bridge) external;
    function removeBridge(address bridge) external;
    
    function bridgeTokens(
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 targetChainId
    ) external;
    
    function mintBridgedTokens(
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 fromChainId
    ) external;

    // ERC-7579 functions
    function setSafe(uint256 tokenId, bool safe) external;
    function isSafe(address owner, uint256 tokenId) external view returns (bool);
    function setFunctionRestriction(uint256 tokenId, bytes4 functionSig, bool restricted) external;
    function isFunctionRestricted(address owner, uint256 tokenId, bytes4 functionSig) external view returns (bool);
}