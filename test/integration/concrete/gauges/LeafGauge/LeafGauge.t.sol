// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract LeafGaugeTest is BaseForkFixture {
    uint256 constant DURATION = 7 days;

    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: leafId});
        skipToNextEpoch(0); // warp to start of next epoch
        deal(address(leafXVelo), address(leafMessageModule), TOKEN_1);
        deal(address(leafXVelo), leafGaugeFactory.notifyAdmin(), TOKEN_1);
        _addLiquidityToPool(users.alice, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);
    }

    function test_InitialState() public view {
        assertEq(leafGauge.stakingToken(), address(leafPool));
        assertEq(leafGauge.feesVotingReward(), address(leafFVR));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.voter(), address(leafVoter));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));
        assertEq(leafGauge.gaugeFactory(), address(leafGaugeFactory));
        assertTrue(leafGauge.isPool());
    }

    function testCannotDepositWithRecipientZeroAmount() public {
        vm.expectRevert(ILeafGauge.ZeroAmount.selector);
        leafGauge.deposit(0, users.bob);
    }

    function testCannotDepositWithRecipientWithKilledGauge() public {
        vm.prank(address(leafMessageModule));
        leafVoter.killGauge(address(leafGauge));

        vm.expectRevert(ILeafGauge.NotAlive.selector);
        leafGauge.deposit(POOL_1, users.bob);
    }

    function testDepositWithRecipient() public {
        assertEq(leafGauge.totalSupply(), 0);

        // deposit to users.charlie from users.alice
        vm.startPrank(users.alice);
        uint256 pre = leafPool.balanceOf(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.Deposit(users.alice, users.charlie, POOL_1);
        leafGauge.deposit(POOL_1, users.charlie);
        vm.stopPrank();
        uint256 post = leafPool.balanceOf(users.alice);

        assertEq(leafGauge.totalSupply(), POOL_1);
        assertEq(leafGauge.earned(users.charlie), 0);
        assertEq(leafGauge.balanceOf(users.charlie), POOL_1);
        assertEq(pre - post, POOL_1);

        skip(1 hours);
        _addLiquidityToPool(users.bob, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);

        skip(1 hours);
        // deposit to users.deployer from users.bob
        pre = leafPool.balanceOf(users.bob);
        vm.prank(users.bob);
        leafPool.approve(address(leafGauge), POOL_1);
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.Deposit(users.bob, users.deployer, POOL_1);
        vm.prank(users.bob);
        leafGauge.deposit(POOL_1, users.deployer);
        post = leafPool.balanceOf(users.bob);

        assertEq(leafGauge.totalSupply(), POOL_1 * 2);
        assertEq(leafGauge.earned(users.deployer), 0);
        assertEq(leafGauge.balanceOf(users.deployer), POOL_1);
        assertEq(pre - post, POOL_1);
    }

    function testCannotDepositZeroAmount() public {
        vm.expectRevert(ILeafGauge.ZeroAmount.selector);
        leafGauge.deposit(0);
    }

    function testCannotDepositWithKilledGauge() public {
        vm.prank(address(leafMessageModule));
        leafVoter.killGauge(address(leafGauge));

        vm.expectRevert(ILeafGauge.NotAlive.selector);
        leafGauge.deposit(POOL_1);
    }

    function testDeposit() public {
        assertEq(leafGauge.totalSupply(), 0);

        vm.startPrank(users.alice);
        uint256 pre = leafPool.balanceOf(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.Deposit(users.alice, users.alice, POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();
        uint256 post = leafPool.balanceOf(users.alice);

        assertEq(leafGauge.totalSupply(), POOL_1);
        assertEq(leafGauge.earned(users.alice), 0);
        assertEq(leafGauge.balanceOf(users.alice), POOL_1);
        assertEq(pre - post, POOL_1);

        skip(1 hours);
        _addLiquidityToPool(users.bob, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);

        skip(1 hours);
        pre = leafPool.balanceOf(users.bob);
        vm.prank(users.bob);
        leafPool.approve(address(leafGauge), POOL_1);
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.Deposit(users.bob, users.bob, POOL_1);
        vm.prank(users.bob);
        leafGauge.deposit(POOL_1);
        post = leafPool.balanceOf(users.bob);

        assertEq(leafGauge.totalSupply(), POOL_1 * 2);
        assertEq(leafGauge.earned(users.bob), 0);
        assertEq(leafGauge.balanceOf(users.bob), POOL_1);
        assertEq(pre - post, POOL_1);
    }

    function testWithdrawWithDepositWithNoRecipient() public {
        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        _addLiquidityToPool(users.bob, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();
        assertEq(leafGauge.balanceOf(users.bob), POOL_1);

        skip(1 hours);

        uint256 pre = leafPool.balanceOf(users.alice);
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.Withdraw(users.alice, POOL_1);
        vm.prank(users.alice);
        leafGauge.withdraw(POOL_1);
        uint256 post = leafPool.balanceOf(users.alice);

        assertEq(leafGauge.totalSupply(), POOL_1);
        assertEq(leafGauge.earned(users.alice), 0);
        assertEq(leafGauge.balanceOf(users.alice), 0);
        assertEq(post - pre, POOL_1);

        skip(1 hours);

        pre = leafPool.balanceOf(users.bob);
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.Withdraw(users.bob, POOL_1);
        vm.prank(users.bob);
        leafGauge.withdraw(POOL_1);
        post = leafPool.balanceOf(users.bob);

        assertEq(leafGauge.totalSupply(), 0);
        assertEq(leafGauge.earned(users.bob), 0);
        assertEq(leafGauge.balanceOf(users.bob), 0);
        assertEq(post - pre, POOL_1);
    }

    function testWithdrawWithDepositWithRecipient() public {
        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        _addLiquidityToPool(users.bob, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1, users.charlie);
        vm.stopPrank();
        assertEq(leafGauge.balanceOf(users.bob), 0);
        assertEq(leafGauge.balanceOf(users.charlie), POOL_1);

        skip(1 hours);

        uint256 pre = leafPool.balanceOf(users.alice);
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.Withdraw(users.alice, POOL_1);
        vm.prank(users.alice);
        leafGauge.withdraw(POOL_1);
        uint256 post = leafPool.balanceOf(users.alice);

        assertEq(leafGauge.totalSupply(), POOL_1);
        assertEq(leafGauge.earned(users.alice), 0);
        assertEq(leafGauge.balanceOf(users.alice), 0);
        assertEq(post - pre, POOL_1);

        skip(1 hours);

        pre = leafPool.balanceOf(users.charlie);
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.Withdraw(users.charlie, POOL_1);
        vm.prank(users.charlie);
        leafGauge.withdraw(POOL_1);
        post = leafPool.balanceOf(users.charlie);

        assertEq(leafGauge.totalSupply(), 0);
        assertEq(leafGauge.earned(users.charlie), 0);
        assertEq(leafGauge.balanceOf(users.charlie), 0);
        assertEq(post - pre, POOL_1);
    }

    function testGetRewardWithMultipleDepositors() public {
        // add deposits
        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        _addLiquidityToPool(users.bob, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(leafMessageModule), address(leafGauge), reward);

        skip(1 weeks / 2);

        assertApproxEqAbs(leafGauge.earned(users.alice), reward / 4, 1e6);
        assertApproxEqAbs(leafGauge.earned(users.bob), reward / 4, 1e6);

        uint256 pre = leafXVelo.balanceOf(users.alice);
        vm.prank(users.alice);
        leafGauge.getReward(users.alice);
        uint256 post = leafXVelo.balanceOf(users.alice);

        assertApproxEqRel(post - pre, reward / 4, 1e6);

        skip(1 weeks / 2);

        assertApproxEqAbs(leafGauge.earned(users.alice), reward / 4, 1e6);
        assertApproxEqAbs(leafGauge.earned(users.bob), reward / 2, 1e6);

        pre = leafXVelo.balanceOf(users.alice);
        vm.prank(users.alice);
        leafGauge.getReward(users.alice);
        post = leafXVelo.balanceOf(users.alice);

        assertApproxEqRel(post - pre, reward / 4, 1e6);

        pre = leafXVelo.balanceOf(users.bob);
        vm.prank(users.bob);
        leafGauge.getReward(users.bob);
        post = leafXVelo.balanceOf(users.bob);

        assertApproxEqRel(post - pre, reward / 2, 1e6);
    }

    function testGetRewardWithMultipleDepositorsAndEarlyWithdrawal() public {
        // add deposits
        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        _addLiquidityToPool(users.bob, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(leafMessageModule), address(leafGauge), reward);

        skip(1 weeks / 2);

        assertApproxEqRel(leafGauge.earned(users.alice), reward / 4, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), reward / 4, 1e6);

        uint256 pre = leafXVelo.balanceOf(users.alice);
        vm.prank(users.alice);
        leafGauge.getReward(users.alice);
        uint256 post = leafXVelo.balanceOf(users.alice);

        assertApproxEqRel(post - pre, reward / 4, 1e6);

        // users.alice withdraws early after claiming
        vm.prank(users.alice);
        leafGauge.withdraw(POOL_1);

        skip(1 weeks / 2);

        // reward / 2 left to be disbursed to users.bob over the remainder of the week
        assertApproxEqRel(leafGauge.earned(users.alice), 0, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), (3 * reward) / 4, 1e6);

        pre = leafXVelo.balanceOf(users.bob);
        vm.prank(users.bob);
        leafGauge.getReward(users.bob);
        post = leafXVelo.balanceOf(users.bob);

        assertApproxEqRel(post - pre, (3 * reward) / 4, 1e6);
    }

    function testEarnedWithStaggeredDepositsAndWithdrawals() public {
        // add deposits
        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(leafMessageModule), address(leafGauge), reward);

        skip(1 days);

        // single deposit, 1/7th of epoch
        assertApproxEqRel(leafGauge.earned(users.alice), reward / 7, 1e6);
        vm.prank(users.alice);
        leafGauge.getReward(users.alice);

        _addLiquidityToPool(users.bob, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);
        vm.startPrank(users.bob);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        skip(1 days);
        // two deposits, equal in size, 1/7th of epoch
        uint256 expectedReward = reward / 7 / 2;
        assertApproxEqRel(leafGauge.earned(users.alice), expectedReward, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), expectedReward, 1e6);
        vm.prank(users.alice);
        leafGauge.getReward(users.alice);
        vm.prank(users.bob);
        leafGauge.getReward(users.bob);

        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);

        skip(1 days);
        // two deposits, users.alice with twice the size of users.bob, 1/7th of epoch
        expectedReward = reward / 7 / 3;
        assertApproxEqRel(leafGauge.earned(users.alice), expectedReward * 2, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), expectedReward, 1e6);
        leafGauge.getReward(users.alice);
        vm.stopPrank();
        vm.startPrank(users.bob);
        leafGauge.getReward(users.bob);

        leafGauge.withdraw(POOL_1 / 2);

        skip(1 days);
        // two deposits, users.alice with four times the size of users.bob, 1/7th of epoch
        expectedReward = reward / 7 / 5;
        assertApproxEqRel(leafGauge.earned(users.alice), expectedReward * 4, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), expectedReward, 1e6);
    }

    function testEarnedWithStaggeredDepositsAndWithdrawalsWithoutIntermediateClaims() public {
        // add deposits
        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(leafMessageModule), address(leafGauge), reward);

        skip(1 days);

        // single deposit, 1/7th of epoch
        uint256 ownerBal = reward / 7;
        assertApproxEqRel(leafGauge.earned(users.alice), reward / 7, 1e6);

        _addLiquidityToPool(users.bob, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);
        vm.startPrank(users.bob);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        skip(1 days);
        // two deposits, equal in size, 1/7th of epoch
        ownerBal += (reward / 7) / 2;
        uint256 owner2Bal = (reward / 7) / 2;
        assertApproxEqRel(leafGauge.earned(users.alice), ownerBal, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), owner2Bal, 1e6);

        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        skip(1 days);
        // two deposits, users.alice with twice the size of users.bob, 1/7th of epoch
        ownerBal += ((reward / 7) / 3) * 2;
        owner2Bal += (reward / 7) / 3;
        assertApproxEqRel(leafGauge.earned(users.alice), ownerBal, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), owner2Bal, 1e6);

        vm.prank(users.bob);
        leafGauge.withdraw(POOL_1 / 2);

        skip(1 days);
        // two deposits, users.alice with four times the size of users.bob, 1/7th of epoch
        ownerBal += ((reward / 7) / 5) * 4;
        owner2Bal += (reward / 7) / 5;
        assertApproxEqRel(leafGauge.earned(users.alice), ownerBal, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), owner2Bal, 1e6);
    }

    function testGetRewardWithLateRewards() public {
        // add deposits
        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        _addLiquidityToPool(users.bob, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        skip(1 weeks / 2);

        // reward added late in epoch
        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(leafMessageModule), address(leafGauge), reward);
        uint256 expectedRewardRate = reward / (DURATION / 2);
        assertApproxEqRel(leafGauge.rewardRate(), expectedRewardRate, 1e6);

        skipToNextEpoch(0);
        // half the epoch has passed, all rewards distributed
        uint256 expectedReward = reward / 2;
        assertApproxEqRel(leafGauge.earned(users.alice), expectedReward, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), expectedReward, 1e6);
        vm.prank(users.alice);
        leafGauge.getReward(users.alice);
        assertEq(leafGauge.earned(users.alice), 0);

        skip(1 days);
        uint256 reward2 = TOKEN_1 * 2;
        expectedRewardRate = reward2 / (6 days);
        _addRewardToGauge(address(leafMessageModule), address(leafGauge), reward2);
        assertApproxEqRel(leafGauge.rewardRate(), expectedRewardRate, 1e6);

        skip(1 days);
        assertApproxEqRel(leafGauge.earned(users.alice), reward2 / 2 / 6, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), reward / 2 + reward2 / 2 / 6, 1e6);

        skipToNextEpoch(0);
        assertApproxEqRel(leafGauge.earned(users.alice), reward2 / 2, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), (reward + reward2) / 2, 1e6);

        uint256 pre = leafXVelo.balanceOf(users.alice);
        vm.prank(users.alice);
        leafGauge.getReward(users.alice);
        uint256 post = leafXVelo.balanceOf(users.alice);
        assertApproxEqRel(post - pre, reward2 / 2, 1e6);

        pre = leafXVelo.balanceOf(users.bob);
        vm.prank(users.bob);
        leafGauge.getReward(users.bob);
        post = leafXVelo.balanceOf(users.bob);

        assertApproxEqRel(post - pre, (reward + reward2) / 2, 1e6);
    }

    function testGetRewardWithNonOverlappingRewards() public {
        // add deposits
        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        _addLiquidityToPool(users.bob, address(leafRouter), address(token0), address(token1), false, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(leafMessageModule), address(leafGauge), reward);
        uint256 expectedRewardRate = TOKEN_1 / DURATION;
        assertApproxEqRel(leafGauge.rewardRate(), expectedRewardRate, 1e6);

        skipToNextEpoch(0);
        uint256 expectedReward = reward / 2;
        assertApproxEqRel(leafGauge.earned(users.alice), expectedReward, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), expectedReward, 1e6);

        skip(1 days); // rewards distributed over 6 days intead of 7
        uint256 reward2 = TOKEN_1 * 2;
        _addRewardToGauge(address(leafMessageModule), address(leafGauge), reward2);
        expectedRewardRate = reward2 / (6 days);
        assertApproxEqRel(leafGauge.rewardRate(), expectedRewardRate, 1e6);

        skip(1 days); // accrue 1/6 th of remaining rewards
        expectedReward = reward / 2 + reward2 / 2 / 6;
        assertApproxEqRel(leafGauge.earned(users.alice), expectedReward, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), expectedReward, 1e6);

        skipToNextEpoch(0); // accrue all of remaining rewards
        expectedReward = (reward + reward2) / 2;
        assertApproxEqRel(leafGauge.earned(users.alice), expectedReward, 1e6);
        assertApproxEqRel(leafGauge.earned(users.bob), expectedReward, 1e6);
    }

    function testNotifyRewardsWithoutClaimAfterClaimingFees() public {
        uint256 reward = TOKEN_1;
        vm.startPrank(address(leafMessageModule));
        leafXVelo.approve(address(leafGauge), reward);
        LeafGauge(leafGauge).notifyRewardAmount(reward);
        vm.stopPrank();

        uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        assertApproxEqRel(leafGauge.rewardRate(), reward / DURATION, 1e6);
        assertApproxEqRel(leafGauge.rewardRateByEpoch(epochStart), reward / DURATION, 1e6);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), TOKEN_1);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), epochStart + DURATION);

        skipTime(1 days);

        address notifyAdmin = leafGaugeFactory.notifyAdmin();
        vm.startPrank(notifyAdmin);
        leafXVelo.approve(address(leafGauge), reward);
        vm.expectCall(LeafGauge(leafGauge).stakingToken(), abi.encodeCall(IPool.claimFees, ()), 0);
        leafGauge.notifyRewardWithoutClaim(reward);
        vm.stopPrank();

        uint256 prevReward = (reward * 6) / 7; // Only 6/7 of previously added rewards are available after 1 day
        reward = TOKEN_1 + prevReward; // Rewards available = newly emitted rewards + previous rewards

        epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        assertApproxEqRel(leafGauge.rewardRate(), (reward / (6 days)), 1e6);
        assertApproxEqRel(leafGauge.rewardRateByEpoch(epochStart), reward / (6 days), 1e6);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 2 * TOKEN_1);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), epochStart + DURATION);
    }

    function testCannotGetRewardIfNotOwnerOrVoter() public {
        // add deposits
        vm.startPrank(users.alice);
        leafPool.approve(address(leafGauge), POOL_1);
        leafGauge.deposit(POOL_1);
        vm.stopPrank();

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(leafMessageModule), address(leafGauge), reward);

        vm.expectRevert(ILeafGauge.NotAuthorized.selector);
        vm.prank(users.bob);
        leafGauge.getReward(users.alice);

        skip(1 days);

        uint256 pre = leafXVelo.balanceOf(users.alice);
        vm.prank(users.alice);
        leafGauge.getReward(users.alice);
        uint256 post = leafXVelo.balanceOf(users.alice);

        assertApproxEqRel(post - pre, reward / 7, 1e6);

        skip(1 days);

        pre = leafXVelo.balanceOf(users.alice);
        vm.prank(address(leafVoter));
        leafGauge.getReward(users.alice);
        post = leafXVelo.balanceOf(users.alice);

        assertApproxEqRel(post - pre, reward / 7, 1e6);
    }

    /// @dev Helper function to deposit liquidity into pool
    function _addLiquidityToPool(
        address _owner,
        address _router,
        address _token0,
        address _token1,
        bool _stable,
        uint256 _amount0,
        uint256 _amount1
    ) internal {
        vm.startPrank(_owner);
        deal(_token0, _owner, _amount0);
        deal(_token1, _owner, _amount1);
        IERC20(_token0).approve(address(_router), _amount0);
        IERC20(_token1).approve(address(_router), _amount1);
        Router(payable(_router)).addLiquidity(
            _token0, _token1, _stable, _amount0, _amount1, 0, 0, address(_owner), block.timestamp
        );
        vm.stopPrank();
    }

    /// @dev Helper function to add rewards to gauge from voter
    function _addRewardToGauge(address _voter, address _gauge, uint256 _amount) internal {
        deal(address(leafXVelo), _voter, _amount);
        vm.startPrank(_voter);
        // do not overwrite approvals if already set
        if (leafXVelo.allowance(_voter, _gauge) < _amount) {
            leafXVelo.approve(_gauge, _amount);
        }
        LeafGauge(_gauge).notifyRewardAmount(_amount);
        vm.stopPrank();
    }
}
