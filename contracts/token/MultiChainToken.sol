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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "../interfaces/IMultiChainToken.sol";

abstract contract MultiChainToken is ERC20, Ownable, ReentrancyGuard, ERC165, ERC2771Context {
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant BRIDGE_TYPEHASH = keccak256(
        "Bridge(address to,uint256 amount,uint256 nonce,uint256 targetChainId)"
    );
    bytes32 private immutable DOMAIN_SEPARATOR;
    
    mapping(address => bool) public bridgeAddresses;
    mapping(uint256 => bool) public processedNonces;
    uint256 public chainId;

    // ERC-7579 variables
    mapping(address => mapping(uint256 => bool)) private _isSafe;
    mapping(address => mapping(uint256 => mapping(bytes4 => bool))) private _restrictedFunctions;
    
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

    constructor(
        string memory name,
        string memory symbol,
        uint256 _chainId,
        address trustedForwarder
    ) ERC20(name, symbol) Ownable(msg.sender) ERC2771Context(trustedForwarder) {
        chainId = _chainId;
        
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IMultiChainToken).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // ERC-7579 functions
    function setSafe(uint256 tokenId, bool safe) external {
        require(msg.sender == owner() || _isSafe[msg.sender][tokenId], "Not authorized");
        _isSafe[msg.sender][tokenId] = safe;
        emit SafeUpdated(msg.sender, tokenId, safe);
    }

    function isSafe(address owner, uint256 tokenId) public view returns (bool) {
        return _isSafe[owner][tokenId];
    }

    function setFunctionRestriction(
        uint256 tokenId,
        bytes4 functionSig,
        bool restricted
    ) external {
        require(_isSafe[msg.sender][tokenId], "Not a safe");
        _restrictedFunctions[msg.sender][tokenId][functionSig] = restricted;
        emit FunctionRestrictionUpdated(msg.sender, tokenId, functionSig, restricted);
    }

    function isFunctionRestricted(
        address owner,
        uint256 tokenId,
        bytes4 functionSig
    ) public view returns (bool) {
        return _restrictedFunctions[owner][tokenId][functionSig];
    }

    // Bridge functions
    function getDomainSeparator() public view returns (bytes32) {
        return DOMAIN_SEPARATOR;
    }

    function addBridge(address bridge) external onlyOwner {
        bridgeAddresses[bridge] = true;
    }

    function removeBridge(address bridge) external onlyOwner {
        bridgeAddresses[bridge] = false;
    }

    function bridgeTokens(
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 targetChainId
    ) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(targetChainId != chainId, "Cannot bridge to same chain");
        require(!processedNonces[nonce], "Nonce already processed");
        
        processedNonces[nonce] = true;
        _burn(_msgSender(), amount);
        
        emit TokensBridged(
            _msgSender(),
            to,
            amount,
            nonce,
            chainId,
            targetChainId
        );
    }

    function mintBridgedTokens(
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 fromChainId
    ) external nonReentrant {
        require(bridgeAddresses[_msgSender()], "Not authorized bridge");
        require(!processedNonces[nonce], "Nonce already processed");
        require(fromChainId != chainId, "Invalid source chain");
        
        processedNonces[nonce] = true;
        _mint(to, amount);
    }

     function _msgSender() internal view virtual override(Context, ERC2771Context)
        returns (address sender) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view virtual override(Context, ERC2771Context)
        returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength() internal view virtual override(ERC2771Context, Context) returns (uint256) {
        return 0;
    }

    // Additional ERC-7579 hooks
   // Additional ERC-7579 hooks - Function restriction check
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Check if transfer is restricted for any involved safes
        bytes4 transferSig = bytes4(keccak256("transfer(address,uint256)"));
        require(
            !_restrictedFunctions[from][amount][transferSig],
            "Transfer restricted by safe"
        );
        super._update(from, to, amount);
    }

}
