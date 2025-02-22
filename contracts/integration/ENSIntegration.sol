// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../naming/DegenENS.sol";
import "../factory/TokenFactory.sol";
import "../BonkWars.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Degen4LifeController.sol";
/**
 * @title ENSIntegration
 * @author Degen4Life Team
 * @notice Helper contract for integrating DegenENS with TokenFactory and BonkWars
 */
contract ENSIntegration {
    using SafeERC20 for IERC20;

    DegenENS public immutable ens;
    TokenFactory public immutable factory;
    BonkWars public immutable bonkWars;
    IERC20 public immutable usdt;
    IERC20 public immutable weth;

    uint256 public constant REGISTRATION_FEE_USDT = 100 * 1e6; // 100 USDT
    uint256 public constant REGISTRATION_FEE_WETH = 0.05 * 1e18; // 0.05 WETH
    uint256 public constant INITIAL_MARKET_DURATION = 7 days;
    uint256 public constant INITIAL_MCAP_THRESHOLD = 250_000 * 1e18; // $250K USD
    uint256 public constant INITIAL_SOCIAL_THRESHOLD = 1000 * 1e18; // 1000 actions

    event TokenRegistered(
        address indexed token,
        string name,
        string symbol,
        address indexed paymentToken,
        uint256 paymentAmount,
        bytes32 marketCapMarketId,
        bytes32 socialMarketId
    );

    constructor(
        address _ens,
        address _factory,
        address _bonkWars,
        address _usdt,
        address _weth
    ) {
        ens = DegenENS(_ens);
        factory = TokenFactory(payable(_factory));
        bonkWars = BonkWars(_bonkWars);
        usdt = IERC20(_usdt);
        weth = IERC20(_weth);
    }

    /**
     * @notice Hook to be called after meme coin creation with USDT payment
     */
    function registerMemeTokenWithUSDT(
        bytes32 memeId,
        address tokenAddress,
        string calldata name,
        string calldata symbol
    ) external {
        // Transfer USDT from sender
        usdt.safeTransferFrom(msg.sender, address(this), REGISTRATION_FEE_USDT);
        
        // Register the name and create prediction markets
        (bytes32 mcapMarketId, bytes32 socialMarketId) = _registerTokenAndCreateMarkets(
            memeId, 
            tokenAddress, 
            name, 
            symbol
        );
        
        emit TokenRegistered(
            tokenAddress, 
            name, 
            symbol, 
            address(usdt), 
            REGISTRATION_FEE_USDT,
            mcapMarketId,
            socialMarketId
        );
    }

    /**
     * @notice Hook to be called after meme coin creation with WETH payment
     */
    function registerMemeTokenWithWETH(
        bytes32 memeId,
        address tokenAddress,
        string calldata name,
        string calldata symbol
    ) external {
        // Transfer WETH from sender
        weth.safeTransferFrom(msg.sender, address(this), REGISTRATION_FEE_WETH);
        
        // Register the name and create prediction markets
        (bytes32 mcapMarketId, bytes32 socialMarketId) = _registerTokenAndCreateMarkets(
            memeId, 
            tokenAddress, 
            name, 
            symbol
        );
        
        emit TokenRegistered(
            tokenAddress, 
            name, 
            symbol, 
            address(weth), 
            REGISTRATION_FEE_WETH,
            mcapMarketId,
            socialMarketId
        );
    }

    /**
     * @notice Internal function to handle token registration and create prediction markets
     */
    function _registerTokenAndCreateMarkets(
        bytes32 memeId,
        address tokenAddress,
        string calldata name,
        string calldata symbol
    ) internal returns (bytes32 mcapMarketId, bytes32 socialMarketId) {
        // Only allow factory to call this
        require(msg.sender == TokenFactory(factory).owner(), "Only controller");

        // Register the name in ENS
        ens.registerName(name, tokenAddress, 365 days);

        // Update token status in BonkWars
        bonkWars.updateTokenStatus(tokenAddress);

        // Create market cap prediction market
        mcapMarketId = bonkWars.createMarket(
            tokenAddress,
            INITIAL_MCAP_THRESHOLD,
            INITIAL_MARKET_DURATION,
            BonkWars.MarketType.MARKET_CAP
        );

        // Create social engagement prediction market
        socialMarketId = bonkWars.createMarket(
            tokenAddress,
            INITIAL_SOCIAL_THRESHOLD,
            INITIAL_MARKET_DURATION,
            BonkWars.MarketType.SOCIAL_ENGAGEMENT
        );
    }

    /**
     * @notice Withdraw collected fees to treasury
     * @param token The token to withdraw (USDT or WETH)
     */
    function withdrawFees(address token) external {
        require(msg.sender == factory.owner(), "Only controller");
        require(token == address(usdt) || token == address(weth), "Invalid token");
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(factory.treasuryWallet(), balance);
        }
    }
}
