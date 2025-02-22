// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/tokens/D4LToken.sol";
import "../contracts/interfaces/IContractRegistry.sol";
import "../contracts/interfaces/ITokenomics.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

error OwnableUnauthorizedAccount(address account);

contract D4LTokenTest is Test {
    D4LToken public implementation;
    D4LToken public token;
    address public owner;
    address public user1;
    address public user2;
    address public registry;
    address public tokenomics;
    address public governanceAddress;
    address public teamWallet;
    address public advisorsWallet;
    address public ecosystemWallet;
    address public liquidityWallet;
    address public communityWallet;
    address public trustedForwarder;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event TokensVested(address indexed beneficiary, uint256 amount);
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event TokensBridged(address indexed from, address indexed to, uint256 amount, uint256 nonce, uint256 fromChainId, uint256 toChainId);
    event SafeUpdated(address indexed owner, uint256 indexed tokenId, bool isSafe);
    event FunctionRestrictionUpdated(address indexed owner, uint256 indexed tokenId, bytes4 indexed functionSig, bool isRestricted);
    event VestingScheduleRevoked(address indexed beneficiary);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        registry = makeAddr("registry");
        tokenomics = makeAddr("tokenomics");
        governanceAddress = makeAddr("governance");
        teamWallet = makeAddr("team");
        advisorsWallet = makeAddr("advisors");
        ecosystemWallet = makeAddr("ecosystem");
        liquidityWallet = makeAddr("liquidity");
        communityWallet = makeAddr("community");
        trustedForwarder = makeAddr("forwarder");

        // Deploy implementation
        implementation = new D4LToken();
        
        // Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            D4LToken.initialize.selector,
            registry,
            tokenomics,
            governanceAddress,
            teamWallet,
            advisorsWallet,
            ecosystemWallet,
            liquidityWallet,
            communityWallet,
            trustedForwarder
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        // Get token instance
        token = D4LToken(address(proxy));

        // Mock tokenomics functions
        vm.mockCall(
            tokenomics,
            abi.encodeWithSelector(ITokenomics.calculateTotalFees.selector),
            abi.encode(0)
        );

        vm.mockCall(
            tokenomics,
            abi.encodeWithSelector(ITokenomics.distributeFees.selector),
            abi.encode()
        );

        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function test_InitialSetup() public view {
        assertEq(token.name(), "Degen4Life");
        assertEq(token.symbol(), "D4L");
        assertEq(token.decimals(), 18);
        assertEq(token.owner(), owner);
        assertEq(address(token.registry()), registry);
        assertEq(address(token.tokenomics()), tokenomics);
        assertEq(token.governanceAddress(), governanceAddress);
    }

    function test_InitialSupplyAndAllocation() public view {
        uint256 initialSupply = token.getInitialSupply();
        assertEq(token.totalSupply(), initialSupply);

        // Check allocations
        uint256 teamAllocation = (initialSupply * token.getTeamAllocation()) / 10000;
        uint256 advisorsAllocation = (initialSupply * token.getAdvisorsAllocation()) / 10000;
        uint256 ecosystemAllocation = (initialSupply * token.getEcosystemAllocation()) / 10000;
        uint256 liquidityAllocation = (initialSupply * token.getLiquidityAllocation()) / 10000;
        uint256 communityAllocation = (initialSupply * token.getCommunityAllocation()) / 10000;

        // Check vesting schedules
        (uint256 teamTotal,,,,,,,) = token.vestingSchedules(teamWallet);
        (uint256 advisorsTotal,,,,,,,) = token.vestingSchedules(advisorsWallet);
        (uint256 ecosystemTotal,,,,,,,) = token.vestingSchedules(ecosystemWallet);

        assertEq(teamTotal, teamAllocation);
        assertEq(advisorsTotal, advisorsAllocation);
        assertEq(ecosystemTotal, ecosystemAllocation);
        assertEq(token.balanceOf(liquidityWallet), liquidityAllocation);
        assertEq(token.balanceOf(communityWallet), communityAllocation);
    }

    function test_Staking() public {
        uint256 stakeAmount = 1000e18;
        
        // Transfer tokens to user1
        vm.startPrank(communityWallet);
        token.transfer(user1, stakeAmount);
        vm.stopPrank();

        // Stake tokens
        vm.startPrank(user1);
        token.approve(address(token), stakeAmount);
        
        vm.expectEmit(true, true, false, true);
        emit Staked(user1, stakeAmount);
        token.stake(stakeAmount);

        assertEq(token.stakedBalance(user1), stakeAmount);
        assertEq(token.balanceOf(user1), 0);
        vm.stopPrank();
    }

    function test_Unstaking() public {
        uint256 stakeAmount = 1000e18;
        
        // Setup staking
        vm.startPrank(communityWallet);
        token.transfer(user1, stakeAmount);
        vm.stopPrank();

        vm.startPrank(user1);
        token.approve(address(token), stakeAmount);
        token.stake(stakeAmount);

        // Test unstaking
        vm.expectEmit(true, true, false, true);
        emit Unstaked(user1, stakeAmount);
        token.unstake(stakeAmount);

        assertEq(token.stakedBalance(user1), 0);
        assertEq(token.balanceOf(user1), stakeAmount);
        vm.stopPrank();
    }

    function test_VestingSchedule() public {
        // Fast forward past cliff period
        vm.warp(block.timestamp + token.getCliffDuration() + 30 days);

        // Test team vesting
        vm.startPrank(teamWallet);
        
        // Calculate expected vesting amount
        uint256 totalAmount = (token.getInitialSupply() * token.getTeamAllocation()) / 10000;
        uint256 timeFromStart = 30 days;  // Time since cliff ended
        uint256 vestingTime = token.getVestingDuration() - token.getCliffDuration();
        uint256 expectedVested = (totalAmount * timeFromStart) / vestingTime;
        
        require(expectedVested > 0, "Expected vesting amount should be > 0");

        vm.expectEmit(true, true, false, true);
        emit TokensVested(teamWallet, expectedVested);
        token.claimVestedTokens();

        assertEq(token.balanceOf(teamWallet), expectedVested);
        vm.stopPrank();
    }

    function test_RevertWhenUnstakingMoreThanStaked() public {
        vm.startPrank(user1);
        vm.expectRevert("Insufficient staked balance");
        token.unstake(1000e18);
        vm.stopPrank();
    }

    function test_RevertWhenStakingWithInsufficientBalance() public {
        vm.startPrank(user1);
        vm.expectRevert("Insufficient balance");
        token.stake(1000e18);
        vm.stopPrank();
    }

    function test_RevertWhenClaimingBeforeCliff() public {
        vm.startPrank(teamWallet);
        vm.expectRevert("Cliff not ended");
        token.claimVestedTokens();
        vm.stopPrank();
    }

    function test_StakingRewards() public {
        uint256 stakeAmount = 100e18;
        uint256 stakingDuration = 30 days;

        // Burn some tokens to make room for rewards
        vm.startPrank(communityWallet);
        uint256 burnAmount = token.balanceOf(communityWallet) - 1000e18;
        token.bridgeTokens(address(0), burnAmount, 2, 56);
        vm.stopPrank();

        // Transfer tokens to user1
        vm.startPrank(communityWallet);
        token.transfer(user1, stakeAmount);
        vm.stopPrank();

        // Stake tokens
        vm.startPrank(user1);
        token.approve(address(token), stakeAmount);
        token.stake(stakeAmount);

        // Fast forward time
        vm.warp(block.timestamp + stakingDuration);

        // Get pending rewards from contract
        uint256 pendingReward = token.pendingRewards(user1);

        // Unstake and check rewards received
        vm.expectEmit(true, true, false, true);
        emit RewardPaid(user1, pendingReward);
        token.unstake(stakeAmount);

        // Verify rewards
        assertEq(token.balanceOf(user1), stakeAmount + pendingReward);
        vm.stopPrank();
    }

    function test_StakingRewardTiers() public {
        // Check community wallet balance
        uint256 communityBalance = token.balanceOf(communityWallet);
        console.log("Community wallet balance:", communityBalance);

        // Burn more tokens to make room for rewards (about 1% of community balance)
        vm.startPrank(communityWallet);
        token.bridgeTokens(address(0), 4_500_000e18, 1, 2);
        vm.stopPrank();

        // Test different staking tiers
        uint256[] memory stakeAmounts = new uint256[](4);
        stakeAmounts[0] = 5_000e18;     // Tier 1: < 10,000 D4L = 100% (base)
        stakeAmounts[1] = 25_000e18;    // Tier 2: 10,000-50,000 D4L = 125%
        stakeAmounts[2] = 75_000e18;    // Tier 3: 50,000-100,000 D4L = 150%
        stakeAmounts[3] = 150_000e18;   // Tier 4: > 100,000 D4L = 200%

        uint256[] memory expectedMultipliers = new uint256[](4);
        expectedMultipliers[0] = 100;
        expectedMultipliers[1] = 125;
        expectedMultipliers[2] = 150;
        expectedMultipliers[3] = 200;

        // Start from initial time
        uint256 startTime = block.timestamp;

        // Test each tier
        for (uint256 i = 0; i < stakeAmounts.length; i++) {
            // Reset time to start for each test
            vm.warp(startTime);

            address staker = address(uint160(i + 1));
            
            // Fund the staker
            vm.startPrank(communityWallet);
            token.transfer(staker, stakeAmounts[i]);
            vm.stopPrank();

            // Stake tokens
            vm.startPrank(staker);
            token.approve(address(token), stakeAmounts[i]);
            token.stake(stakeAmounts[i]);

            // Move forward 30 days
            vm.warp(startTime + 30 days);

            // Calculate expected rewards
            uint256 timeStaked = 30 days;
            uint256 baseReward = (stakeAmounts[i] * timeStaked * 15) / (365 days * 100);
            uint256 expectedReward = (baseReward * expectedMultipliers[i]) / 100;

            // Log reward calculations
            console.log("Tier", i + 1);
            console.log("Stake amount:", stakeAmounts[i]);
            console.log("Base reward:", baseReward);
            console.log("Multiplier:", expectedMultipliers[i]);
            console.log("Expected reward:", expectedReward);
            console.log("Pending reward:", token.pendingRewards(staker));

            // Verify pending rewards with a small tolerance for rounding
            uint256 pendingReward = token.pendingRewards(staker);
            uint256 tolerance = expectedReward / 1_000_000; // 0.0001% tolerance
            assertApproxEqAbs(pendingReward, expectedReward, tolerance, "Unexpected reward amount");

            // Unstake and verify rewards received
            uint256 balanceBefore = token.balanceOf(staker);
            token.unstake(stakeAmounts[i]);
            uint256 actualReward = token.balanceOf(staker) - balanceBefore - stakeAmounts[i];
            assertApproxEqAbs(actualReward, expectedReward, tolerance, "Reward mismatch after unstaking");

            // Move forward 1 second to ensure different stakingStartTime for next test
            vm.warp(block.timestamp + 1);

            vm.stopPrank();
        }
    }

    function test_BridgeTokens() public {
        uint256 amount = 100e18;
        uint256 nonce = 1;
        uint256 targetChainId = 56; // BSC

        // Transfer tokens to user1
        vm.startPrank(communityWallet);
        token.transfer(user1, amount);
        vm.stopPrank();

        // Try bridging before bridge is authorized (should fail)
        vm.startPrank(user1);
        vm.expectRevert("Not authorized bridge");
        token.mintBridgedTokens(user1, amount, nonce, targetChainId);
        vm.stopPrank();

        // Add bridge
        vm.startPrank(owner);
        token.addBridge(address(this));
        vm.stopPrank();

        // Bridge tokens
        vm.startPrank(user1);
        token.approve(address(token), amount);
        vm.expectEmit(true, true, true, true);
        emit TokensBridged(user1, user1, amount, nonce, token.chainId(), targetChainId);
        token.bridgeTokens(user1, amount, nonce, targetChainId);

        // Verify tokens are burned
        assertEq(token.balanceOf(user1), 0);

        // Try to reuse nonce (should fail)
        vm.expectRevert("Nonce already processed");
        token.bridgeTokens(user1, amount, nonce, targetChainId);
        vm.stopPrank();
    }

    function test_BridgeTokenMinting() public {
        uint256 amount = 100e18;
        uint256 nonce = 1;
        uint256 fromChainId = 56; // BSC

        // Burn some tokens to make room for minting
        vm.startPrank(communityWallet);
        token.bridgeTokens(address(0), token.balanceOf(communityWallet) - 1000e18, 2, 56);
        vm.stopPrank();

        // Try minting before bridge is authorized (should fail)
        vm.startPrank(user1);
        vm.expectRevert("Not authorized bridge");
        token.mintBridgedTokens(user1, amount, nonce, fromChainId);
        vm.stopPrank();

        // Add bridge
        vm.startPrank(owner);
        token.addBridge(address(this));
        vm.stopPrank();

        // Mint bridged tokens
        vm.startPrank(address(this));
        token.mintBridgedTokens(user1, amount, nonce, fromChainId);

        // Verify tokens are minted
        assertEq(token.balanceOf(user1), amount);

        // Try to reuse nonce (should fail)
        vm.expectRevert("Nonce already processed");
        token.mintBridgedTokens(user1, amount, nonce, fromChainId);
        vm.stopPrank();
    }

    function test_BridgeManagement() public {
        address bridge = address(0x123);

        // Try adding bridge from non-owner (should fail)
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        token.addBridge(bridge);
        vm.stopPrank();

        // Add bridge
        vm.startPrank(owner);
        token.addBridge(bridge);
        assertTrue(token.bridgeAddresses(bridge));

        // Remove bridge
        token.removeBridge(bridge);
        assertFalse(token.bridgeAddresses(bridge));
        vm.stopPrank();
    }

    function test_SafeManagement() public {
        uint256 tokenId = 1;

        // Try setting safe from non-owner (should fail)
        vm.startPrank(user1);
        vm.expectRevert("Not authorized");
        token.setSafe(tokenId, true);
        vm.stopPrank();

        // Set safe from owner
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit SafeUpdated(owner, tokenId, true);
        token.setSafe(tokenId, true);

        // Verify safe is set
        assertTrue(token.isSafe(owner, tokenId));
        vm.stopPrank();

        // Once a safe is set, it can manage itself
        vm.startPrank(owner);
        token.setSafe(tokenId, false);
        assertFalse(token.isSafe(owner, tokenId));
        vm.stopPrank();
    }

    function test_FunctionRestrictions() public {
        uint256 tokenId = 0;  // Contract uses tokenId 0 for all checks
        bytes4 transferSig = bytes4(keccak256("transfer(address,uint256)"));
        uint256 amount = 100e18;

        // Transfer some tokens to owner for testing
        vm.startPrank(communityWallet);
        token.transfer(owner, amount);
        vm.stopPrank();

        // Set up safe
        vm.startPrank(owner);
        token.setSafe(tokenId, true);

        // Restrict transfer function
        vm.expectEmit(true, true, true, true);
        emit FunctionRestrictionUpdated(owner, tokenId, transferSig, true);
        token.setFunctionRestriction(tokenId, transferSig, true);

        // Verify restriction is set
        assertTrue(token.isFunctionRestricted(owner, tokenId, transferSig));

        // Try to transfer (should fail)
        vm.expectRevert("Transfer restricted by safe");
        token.transfer(user1, amount);

        // Remove restriction
        token.setFunctionRestriction(tokenId, transferSig, false);
        assertFalse(token.isFunctionRestricted(owner, tokenId, transferSig));

        // Transfer should now work
        token.transfer(user1, amount);
        assertEq(token.balanceOf(user1), amount);
        vm.stopPrank();
    }

    function test_MultipleSafes() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        bytes4 transferSig = bytes4(keccak256("transfer(address,uint256)"));

        vm.startPrank(owner);
        
        // Set up multiple safes
        for (uint256 i = 0; i < tokenIds.length; i++) {
            token.setSafe(tokenIds[i], true);
            assertTrue(token.isSafe(owner, tokenIds[i]));

            // Set different restrictions for each safe
            if (i > 0) {
                token.setFunctionRestriction(tokenIds[i], transferSig, true);
                assertTrue(token.isFunctionRestricted(owner, tokenIds[i], transferSig));
            }
        }

        // Verify each safe's restrictions are independent
        assertFalse(token.isFunctionRestricted(owner, tokenIds[0], transferSig));
        assertTrue(token.isFunctionRestricted(owner, tokenIds[1], transferSig));
        assertTrue(token.isFunctionRestricted(owner, tokenIds[2], transferSig));

        vm.stopPrank();
    }

    function test_VestingRevocation() public {
        // Fast forward past cliff period
        vm.warp(block.timestamp + token.getCliffDuration() + 30 days);

        // Calculate expected vesting amount
        uint256 totalAmount = (token.getInitialSupply() * token.getTeamAllocation()) / 10000;
        uint256 timeFromStart = 30 days;
        uint256 vestingTime = token.getVestingDuration() - token.getCliffDuration();
        uint256 expectedVested = (totalAmount * timeFromStart) / vestingTime;

        // Claim some tokens first
        vm.startPrank(teamWallet);
        token.claimVestedTokens();
        vm.stopPrank();

        // Try to revoke from non-owner (should fail)
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        token.revokeVesting(teamWallet);
        vm.stopPrank();

        // Revoke vesting from owner
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit VestingScheduleRevoked(teamWallet);
        token.revokeVesting(teamWallet);

        // Verify schedule is revoked
        (,,,,,, bool revocable, bool revoked) = token.vestingSchedules(teamWallet);
        assertTrue(revocable);
        assertTrue(revoked);
        vm.stopPrank();

        // Try to claim after revocation (should fail)
        vm.startPrank(teamWallet);
        vm.expectRevert("Schedule revoked");
        token.claimVestedTokens();
        vm.stopPrank();
    }

    function test_NonRevocableVesting() public {
        // Ecosystem wallet has non-revocable vesting
        vm.startPrank(owner);
        vm.expectRevert("Schedule not revocable");
        token.revokeVesting(ecosystemWallet);
        vm.stopPrank();

        // Verify schedule is not revoked
        (,,,,,, bool revocable, bool revoked) = token.vestingSchedules(ecosystemWallet);
        assertFalse(revocable);
        assertFalse(revoked);
    }

    function test_VestingScheduleProgression() public {
        // Test vesting at different time points
        uint256[] memory timePoints = new uint256[](4);
        timePoints[0] = token.getCliffDuration() - 1 days;  // Before cliff
        timePoints[1] = token.getCliffDuration() + 90 days; // 25% through vesting
        timePoints[2] = token.getCliffDuration() + 180 days; // 50% through vesting
        timePoints[3] = token.getVestingDuration(); // 100% vested

        uint256 totalAmount = (token.getInitialSupply() * token.getTeamAllocation()) / 10000;
        uint256 vestingTime = token.getVestingDuration() - token.getCliffDuration();
        uint256 lastClaimed = 0;

        // Get initial vesting schedule
        (uint256 scheduleTotal, uint256 startTime,,,,,,) = token.vestingSchedules(teamWallet);
        assertEq(scheduleTotal, totalAmount);

        for (uint256 i = 0; i < timePoints.length; i++) {
            // Move to the next time point
            vm.warp(startTime + timePoints[i]);

            vm.startPrank(teamWallet);
            
            if (i == 0) {
                // Before cliff, should revert
                vm.expectRevert("Cliff not ended");
                token.claimVestedTokens();
            } else {
                uint256 timeFromStart = timePoints[i] - token.getCliffDuration();
                uint256 expectedVested = (totalAmount * timeFromStart) / vestingTime;
                uint256 expectedClaim = expectedVested - lastClaimed;

                if (expectedClaim > 0) {
                    // Get current balance before claiming
                    uint256 balanceBefore = token.balanceOf(teamWallet);

                    // Claim tokens
                    token.claimVestedTokens();

                    // Verify claimed amount
                    uint256 actualClaim = token.balanceOf(teamWallet) - balanceBefore;
                    assertEq(actualClaim, expectedClaim);
                    lastClaimed = expectedVested;
                } else {
                    vm.expectRevert("No tokens to claim");
                    token.claimVestedTokens();
                }
            }

            vm.stopPrank();
        }

        // Verify final balance
        assertEq(token.balanceOf(teamWallet), lastClaimed);
    }
} 