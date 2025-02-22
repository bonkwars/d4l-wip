// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/modules/InsuranceModule.sol";
import "../contracts/interfaces/IContractRegistry.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../contracts/interfaces/IInsurance.sol";
import "../contracts/mocks/MockERC20.sol";

error OwnableUnauthorizedAccount(address account);

contract InsuranceModuleTest is Test {
    InsuranceModule public implementation;
    InsuranceModule public insurance;
    address public owner;
    address public user1;
    address public user2;
    address public registry;
    address public mockToken;

    event PoolCreated(InsuranceModule.CoverageType indexed coverageType, uint256 capacity, uint256 premiumRate);
    event CoveragePurchased(uint256 indexed coverageId, address indexed holder, InsuranceModule.CoverageType coverageType, uint256 amount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed coverageId, uint256 amount);
    event ClaimProcessed(uint256 indexed claimId, InsuranceModule.ClaimStatus status, uint256 amount);
    event StakeAdded(address indexed staker, uint256 amount);
    event StakeWithdrawn(address indexed staker, uint256 amount);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        registry = makeAddr("registry");
        mockToken = makeAddr("token");

        // Deploy implementation
        implementation = new InsuranceModule();
        
        // Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            InsuranceModule.initialize.selector,
            registry
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        // Get insurance instance
        insurance = InsuranceModule(address(proxy));

        // Deploy mock D4L token
        MockERC20 d4lToken = new MockERC20("D4L Token", "D4L", 18);
        vm.mockCall(
            registry,
            abi.encodeWithSelector(IContractRegistry.getContractAddressByName.selector, "D4L_TOKEN"),
            abi.encode(address(d4lToken))
        );

        // Add initial stake to pools
        d4lToken.mint(owner, 1_000_000_000 ether);
        d4lToken.approve(address(insurance), 1_000_000_000 ether);
        insurance.stake(1_000_000_000 ether);

        // Fund test accounts
        d4lToken.mint(user1, 1_000_000 ether);
        vm.prank(user1);
        d4lToken.approve(address(insurance), 1_000_000 ether);

        d4lToken.mint(user2, 1_000_000 ether);
        vm.prank(user2);
        d4lToken.approve(address(insurance), 1_000_000 ether);

        // Mock registry response for D4L token
        vm.mockCall(
            registry,
            abi.encodeWithSelector(IContractRegistry.getContractAddressByName.selector, "D4L_TOKEN"),
            abi.encode(mockToken)
        );

        // Mock token approvals and transfers
        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );

        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );
    }

    function test_InitialSetup() public {
        assertEq(address(insurance.registry()), registry);
        assertEq(insurance.owner(), owner);

        // Check default pools
        (
            uint256 capacity,
            uint256 totalStaked,
            uint256 rate,
            uint256 coverageLimit,
            uint256 minStakeTime,
            uint256 claimDelay,
            bool active
        ) = insurance.pools(InsuranceModule.CoverageType.IMPERMANENT_LOSS);
        assertTrue(active);
        assertEq(rate, 5); // 0.5%
    }

    function test_PurchaseCoverage() public {
        uint256 amount = 1000e18;
        uint256 duration = 30 days;

        vm.startPrank(user1);
        
        uint256 coverageId = insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            amount,
            duration
        );

        // Get coverage details
        (
            address holder,
            uint256 coverageAmount,
            uint256 premium,
            uint256 startTime,
            uint256 endTime,
            InsuranceModule.CoverageType coverageType,
            InsuranceModule.CoverageStatus status
        ) = insurance.coverages(coverageId);

        assertEq(holder, user1);
        assertEq(coverageAmount, amount);
        assertTrue(premium > 0);
        assertEq(endTime - startTime, duration);
        assertEq(uint8(coverageType), uint8(InsuranceModule.CoverageType.IMPERMANENT_LOSS));
        assertEq(uint8(status), uint8(InsuranceModule.CoverageStatus.ACTIVE));

        vm.stopPrank();
    }

    function test_SubmitClaim() public {
        // Purchase coverage first
        vm.startPrank(user1);
        uint256 coverageId = insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            1000e18,
            30 days
        );

        // Submit claim
        uint256 claimAmount = 500e18;
        string memory evidence = "ipfs://evidence";
        uint256 claimId = insurance.submitClaim(coverageId, claimAmount, evidence);

        // Verify claim
        (
            uint256 claimCoverageId,
            uint256 amount,
            uint256 timestamp,
            string memory evidenceHash,
            InsuranceModule.ClaimStatus status
        ) = insurance.claims(claimId);

        assertEq(claimCoverageId, coverageId);
        assertEq(amount, claimAmount);
        assertEq(evidenceHash, evidence);
        assertEq(uint8(status), uint8(InsuranceModule.ClaimStatus.PENDING));

        vm.stopPrank();
    }

    function test_ProcessClaim() public {
        // Setup coverage and claim
        vm.startPrank(user1);
        uint256 coverageId = insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            1000e18,
            30 days
        );
        uint256 claimId = insurance.submitClaim(coverageId, 500e18, "ipfs://evidence");
        vm.stopPrank();

        // Process claim
        vm.startPrank(owner);
        insurance.processClaim(claimId, InsuranceModule.ClaimStatus.APPROVED);

        // Verify status
        (
            uint256 claimCoverageId,
            uint256 amount,
            uint256 timestamp,
            string memory evidenceHash,
            InsuranceModule.ClaimStatus status
        ) = insurance.claims(claimId);
        assertEq(uint8(status), uint8(InsuranceModule.ClaimStatus.APPROVED));

        vm.stopPrank();
    }

    function test_StakeAndWithdraw() public {
        uint256 stakeAmount = 1000e18;

        vm.startPrank(user1);
        
        // Stake tokens
        insurance.stake(stakeAmount);
        assertEq(insurance.stakedBalances(user1), stakeAmount);

        // Move forward past lock period
        vm.warp(block.timestamp + insurance.MIN_COVERAGE_DURATION());

        // Withdraw tokens
        insurance.withdraw(stakeAmount);
        assertEq(insurance.stakedBalances(user1), 0);

        vm.stopPrank();
    }

    function test_RevertWhenInvalidDuration() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid duration");
        insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            1000e18,
            1 days // Less than MIN_COVERAGE_DURATION
        );
        vm.stopPrank();
    }

    function test_RevertWhenExceedsCoverageLimit() public {
        vm.startPrank(user1);
        vm.expectRevert("Exceeds coverage limit");
        insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            10000000e18, // Very large amount
            30 days
        );
        vm.stopPrank();
    }

    function test_RevertWhenUnauthorizedClaim() public {
        // Purchase coverage as user1
        vm.startPrank(user1);
        uint256 coverageId = insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            1000e18,
            30 days
        );
        vm.stopPrank();

        // Try to claim as user2
        vm.startPrank(user2);
        vm.expectRevert("Not coverage holder");
        insurance.submitClaim(coverageId, 500e18, "ipfs://evidence");
        vm.stopPrank();
    }

    function test_RevertWhenClaimingExpiredCoverage() public {
        vm.startPrank(user1);
        uint256 coverageId = insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            1000e18,
            30 days
        );

        // Move past coverage period
        vm.warp(block.timestamp + 31 days);

        vm.expectRevert("Coverage expired");
        insurance.submitClaim(coverageId, 500e18, "ipfs://evidence");
        vm.stopPrank();
    }

    function test_RevertWhenUnauthorizedClaimProcessing() public {
        vm.startPrank(user1);
        uint256 coverageId = insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            1000e18,
            30 days
        );

        uint256 claimId = insurance.submitClaim(
            coverageId,
            500e18,
            "ipfs://evidence"
        );
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user2));
        insurance.processClaim(claimId, InsuranceModule.ClaimStatus.APPROVED);
        vm.stopPrank();
    }

    function test_PoolConfiguration() public {
        (
            uint256 totalCapacity,
            uint256 totalStaked,
            uint256 premiumRate,
            uint256 coverageLimit,
            uint256 minStakeTime,
            uint256 claimDelay,
            bool active
        ) = insurance.pools(InsuranceModule.CoverageType.IMPERMANENT_LOSS);

        assertEq(totalCapacity, 0);
        assertEq(totalStaked, 1_000_000_000 ether);
        assertEq(premiumRate, 5);
        assertEq(coverageLimit, 1000e18);
        assertEq(minStakeTime, 7 days);
        assertEq(claimDelay, 3 days);
        assertTrue(active);
    }

    function test_CoveragePurchase() public {
        vm.startPrank(user1);
        uint256 coverageId = insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            1000e18,
            30 days
        );
        vm.stopPrank();

        (
            address holder,
            uint256 amount,
            uint256 premium,
            ,,,
        ) = insurance.coverages(coverageId);

        assertEq(holder, user1);
        assertEq(amount, 1000e18);
        assertEq(premium, 410958904109589041);
    }

    function test_ClaimProcessing() public {
        // Setup coverage and claim
        uint256 coverageAmount = 1000 ether;
        uint256 duration = 30 days;

        // Purchase coverage
        vm.startPrank(user1);
        uint256 coverageId = insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            coverageAmount,
            duration
        );

        // Submit claim
        string memory evidenceHash = "ipfs://evidence";
        uint256 claimId = insurance.submitClaim(coverageId, coverageAmount, evidenceHash);
        vm.stopPrank();

        // Get claim details
        (
            uint256 claimCoverageId,
            uint256 claimAmount,
            uint256 claimTimestamp,
            string memory evidence,
            InsuranceModule.ClaimStatus status
        ) = insurance.claims(claimId);

        // Verify claim details
        assertEq(claimCoverageId, coverageId);
        assertEq(claimAmount, coverageAmount);
        assertEq(uint8(status), uint8(InsuranceModule.ClaimStatus.PENDING));
    }

    function test_ClaimApproval() public {
        // Setup coverage and claim
        uint256 coverageAmount = 1000 ether;
        uint256 duration = 30 days;

        // Purchase coverage
        vm.startPrank(user1);
        uint256 coverageId = insurance.purchaseCoverage(
            InsuranceModule.CoverageType.IMPERMANENT_LOSS,
            coverageAmount,
            duration
        );

        // Submit claim
        string memory evidenceHash = "ipfs://evidence";
        uint256 claimId = insurance.submitClaim(coverageId, coverageAmount, evidenceHash);
        vm.stopPrank();

        // Process claim
        vm.prank(owner);
        insurance.processClaim(claimId, InsuranceModule.ClaimStatus.APPROVED);

        // Get claim status
        (
            uint256 claimCoverageId,
            uint256 claimAmount,
            uint256 claimTimestamp,
            string memory evidence,
            InsuranceModule.ClaimStatus status
        ) = insurance.claims(claimId);

        // Verify claim status
        assertEq(uint8(status), uint8(InsuranceModule.ClaimStatus.APPROVED));
    }
} 