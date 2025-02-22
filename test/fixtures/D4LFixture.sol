// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/Degen4LifeController.sol";
import "../../contracts/registry/ContractRegistry.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/MockDEX.sol";
import "../../contracts/mocks/MockENS.sol";
import "../../contracts/mocks/MockTokenFactory.sol";
import "../../contracts/mocks/MockSocialModule.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

struct D4LDeployment {
    Degen4LifeController controller;
    ContractRegistry registry;
    MockTokenFactory tokenFactory;
    MockERC20 poolController;
    MockERC20 feeHandler;
    MockERC20 userProfile;
    MockERC20 antiBot;
    MockERC20 antiRugPull;
    MockERC20 hydraCurve;
    MockERC20 socialOracle;
    MockERC20 dao;
    MockERC20 predictionMarket;
    MockERC20 weth;
    MockDEX dex;
    MockENS ens;
    MockSocialModule socialModule;
}

contract D4LFixture is Test {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    function deployD4L(address owner, bool initializeModules) public returns (D4LDeployment memory d) {
        // Deploy Registry
        d.registry = new ContractRegistry();

        // Deploy mock contracts
        d.tokenFactory = new MockTokenFactory();
        d.poolController = new MockERC20("Pool Controller", "PC", 0);
        d.feeHandler = new MockERC20("Fee Handler", "FH", 0);
        d.userProfile = new MockERC20("User Profile", "UP", 0);
        d.antiBot = new MockERC20("Anti Bot", "AB", 0);
        d.antiRugPull = new MockERC20("Anti Rug Pull", "ARP", 0);
        d.hydraCurve = new MockERC20("Hydra Curve", "HC", 0);
        d.socialOracle = new MockERC20("Social Oracle", "SO", 0);
        d.dao = new MockERC20("DAO", "DAO", 0);
        d.predictionMarket = new MockERC20("Prediction Market", "PM", 0);
        d.weth = new MockERC20("Wrapped ETH", "WETH", 1_000_000 ether);
        d.dex = new MockDEX();
        d.ens = new MockENS();
        d.socialModule = new MockSocialModule();

        // Register all contracts in registry
        d.registry.setContractAddress(keccak256("TOKEN_FACTORY"), address(d.tokenFactory));
        d.registry.setContractAddress(keccak256("POOL_CONTROLLER"), address(d.poolController));
        d.registry.setContractAddress(keccak256("FEE_HANDLER"), address(d.feeHandler));
        d.registry.setContractAddress(keccak256("USER_PROFILE"), address(d.userProfile));
        d.registry.setContractAddress(keccak256("ANTI_BOT"), address(d.antiBot));
        d.registry.setContractAddress(keccak256("ANTI_RUGPULL"), address(d.antiRugPull));
        d.registry.setContractAddress(keccak256("HYDRA_CURVE"), address(d.hydraCurve));
        d.registry.setContractAddress(keccak256("SOCIAL_ORACLE"), address(d.socialOracle));
        d.registry.setContractAddress(keccak256("DAO"), address(d.dao));
        d.registry.setContractAddress(keccak256("PREDICTION_MARKET"), address(d.predictionMarket));
        d.registry.setContractAddress(keccak256("WETH"), address(d.weth));
        d.registry.setContractAddress(keccak256("DEX"), address(d.dex));
        d.registry.setContractAddress(keccak256("ENS"), address(d.ens));
        d.registry.setContractAddress(keccak256("SOCIAL_MODULE"), address(d.socialModule));

        // Deploy and initialize controller
        Degen4LifeController implementation = new Degen4LifeController();
        bytes memory controllerInitData = abi.encodeWithSelector(
            Degen4LifeController.initialize.selector,
            address(d.registry)
        );

        ERC1967Proxy controllerProxy = new ERC1967Proxy(
            address(implementation),
            controllerInitData
        );
        d.controller = Degen4LifeController(address(controllerProxy));
        d.registry.setContractAddress(keccak256("CONTROLLER"), address(d.controller));

        // Grant roles to owner
        d.controller.grantRole(DEFAULT_ADMIN_ROLE, owner);
        d.controller.grantRole(keccak256("GOVERNANCE_ADMIN"), owner);
        d.controller.grantRole(keccak256("UPGRADE_ROLE"), owner);

        // Set up system addresses
        Degen4LifeController.SystemAddresses memory systemAddresses = Degen4LifeController.SystemAddresses({
            tokenFactory: address(d.tokenFactory),
            poolController: address(d.poolController),
            feeHandler: address(d.feeHandler),
            userProfile: address(d.userProfile),
            antiBot: address(d.antiBot),
            antiRugPull: address(d.antiRugPull),
            governance: owner,
            hydraCurve: address(d.hydraCurve),
            socialOracle: address(d.socialOracle),
            dao: address(d.dao),
            dex: address(d.dex),
            ens: address(d.ens),
            predictionMarket: address(d.predictionMarket)
        });
        d.controller.setSystemAddresses(systemAddresses);

        // Initialize modules if requested
        if (initializeModules) {
            d.controller.initializeModules(
                address(d.antiBot),
                address(d.antiRugPull),
                address(d.userProfile),
                address(d.poolController),
                address(d.dex),
                address(d.ens),
                address(d.predictionMarket)
            );
        }
    }

    function deployD4L(address owner) public returns (D4LDeployment memory) {
        return deployD4L(owner, false);
    }
} 