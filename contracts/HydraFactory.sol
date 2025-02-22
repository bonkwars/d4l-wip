// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./HydraLPToken.sol";
import "./HydraAMM.sol";

contract HydraFactory {
    mapping(address => mapping(address => address)) public pools;
    address[] public allPools;
    
    event PoolCreated(address indexed tokenX, address indexed tokenY, address pool);

    function createPool(address tokenX, address tokenY) external returns (address pool) {
        require(tokenX != tokenY, "Identical tokens");
        require(pools[tokenX][tokenY] == address(0), "Pool exists");
        
        bytes32 salt = keccak256(abi.encodePacked(tokenX, tokenY));
        HydraLPToken lpToken = new HydraLPToken{salt: salt}();
        pool = address(new HydraAMM{salt: salt}(address(this)));
        
        // Initialize pool with zero liquidity
        HydraAMM(pool).createPool(
            tokenX,
            tokenY,
            0,  // Initial amount X
            0   // Initial amount Y
        );
        pools[tokenX][tokenY] = pool;
        allPools.push(pool);
        
        emit PoolCreated(tokenX, tokenY, pool);
    }
} 