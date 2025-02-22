// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./factory/TokenFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IHydraAMM.sol";


contract MemeStudio {
    TokenFactory public immutable tokenFactory;
    IHydraAMM public immutable hydraAMM;
    
    mapping(string => bool) private _nameUsed;
    mapping(string => bool) private _symbolUsed;
    mapping(string => bool) private _imageHashes;
    
    constructor(address _factory, address _hydraAMM) {
        tokenFactory = TokenFactory(_factory);
        hydraAMM = IHydraAMM(_hydraAMM);
    }

    function createNewToken(
        string memory name,
        string memory symbol,
        string memory imageHash,
        uint256 initialSupply
    ) external returns (address) {
        require(!_nameUsed[name], "Name taken");
        require(!_symbolUsed[symbol], "Symbol taken");
        require(!_imageHashes[imageHash], "Image hash used");
        
        uint256 requiredWETH = IHydraAMM(hydraAMM).calculateInitialDeposit(initialSupply);
        
        IERC20(tokenFactory.WETH()).transferFrom(msg.sender, address(this), requiredWETH);
        
        address newToken = tokenFactory.createToken(
            name,
            symbol,
            initialSupply
        );
        
        IHydraAMM(hydraAMM).createPool(
            newToken,
            tokenFactory.WETH(),
            initialSupply,
            requiredWETH
        );
        
        _nameUsed[name] = true;
        _symbolUsed[symbol] = true;
        _imageHashes[imageHash] = true;
        
        return newToken;
    }
} 