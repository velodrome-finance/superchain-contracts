// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";

contract StakingRewardsTest is BaseFixture {
    Pool public pool;
    StakingRewards public stakingRewards;

    function setUp() public override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        stakingRewards = StakingRewards(
            stakingRewardsFactory.createStakingRewards({
                _forwarder: address(0),
                _pool: address(pool),
                _feesVotingReward: address(0),
                _rewardToken: address(rewardToken),
                isPool: true
            })
        );

        skipToNextEpoch(0);

        addLiquidityToPool(users.alice, address(token0), address(token1), true, TOKEN_1, USDC_1);
        vm.startPrank(users.alice);
    }

    function labelContracts() public override {
        super.labelContracts();
        vm.label(address(pool), "Pool");
        vm.label(address(stakingRewards), "Staking Rewards");
    }

    function testCannotDepositWithRecipientZeroAmount() public {
        vm.expectRevert(IGauge.ZeroAmount.selector);
        stakingRewards.deposit(0, users.alice);
    }

    function testDepositWithRecipient() public {
        assertEq(stakingRewards.totalSupply(), 0);

        uint256 pre = pool.balanceOf(users.alice);
        pool.approve(address(stakingRewards), POOL_1);
        vm.expectEmit(true, true, true, true, address(stakingRewards));
        emit IStakingRewards.Deposit(users.alice, users.bob, POOL_1);
        stakingRewards.deposit(POOL_1, users.bob);
        uint256 post = pool.balanceOf(users.alice);

        assertEq(stakingRewards.totalSupply(), POOL_1);
        assertEq(stakingRewards.earned(users.bob), 0);
        assertEq(stakingRewards.balanceOf(users.bob), POOL_1);
        assertEq(pre - post, POOL_1);

        skip(1 hours);
        addLiquidityToPool(users.bob, address(token0), address(token1), true, TOKEN_1, USDC_1);

        skip(1 hours);
        // deposit to users.owner from users.bob
        pre = pool.balanceOf(users.bob);
        vm.startPrank(users.bob);
        pool.approve(address(stakingRewards), POOL_1);
        vm.expectEmit(true, true, true, true, address(stakingRewards));
        emit IStakingRewards.Deposit(users.bob, users.owner, POOL_1);
        stakingRewards.deposit(POOL_1, users.owner);
        post = pool.balanceOf(users.bob);

        assertEq(stakingRewards.totalSupply(), POOL_1 * 2);
        assertEq(stakingRewards.earned(users.owner), 0);
        assertEq(stakingRewards.balanceOf(users.owner), POOL_1);
        assertEq(pre - post, POOL_1);
    }

    function testCannotDepositZeroAmount() public {
        vm.expectRevert(IGauge.ZeroAmount.selector);
        stakingRewards.deposit(0);
    }

    // function testCannotDepositWithKilledGauge() public {
    //     voter.killGauge(address(stakingRewards));

    //     vm.expectRevert(IGauge.NotAlive.selector);
    //     stakingRewards.deposit(POOL_1);
    // }

    function testDeposit() public {
        assertEq(stakingRewards.totalSupply(), 0);

        uint256 pre = pool.balanceOf(users.alice);
        pool.approve(address(stakingRewards), POOL_1);
        vm.expectEmit(true, true, true, true, address(stakingRewards));
        emit IStakingRewards.Deposit(users.alice, users.alice, POOL_1);
        stakingRewards.deposit(POOL_1);
        uint256 post = pool.balanceOf(users.alice);

        assertEq(stakingRewards.totalSupply(), POOL_1);
        assertEq(stakingRewards.earned(users.alice), 0);
        assertEq(stakingRewards.balanceOf(users.alice), POOL_1);
        assertEq(pre - post, POOL_1);

        skip(1 hours);
        addLiquidityToPool(users.bob, address(token0), address(token1), true, TOKEN_1, USDC_1);

        skip(1 hours);
        pre = pool.balanceOf(users.bob);
        vm.startPrank(users.bob);
        pool.approve(address(stakingRewards), POOL_1);
        vm.expectEmit(true, true, true, true, address(stakingRewards));
        emit IStakingRewards.Deposit(users.bob, users.bob, POOL_1);
        stakingRewards.deposit(POOL_1);
        post = pool.balanceOf(users.bob);

        assertEq(stakingRewards.totalSupply(), POOL_1 * 2);
        assertEq(stakingRewards.earned(users.bob), 0);
        assertEq(stakingRewards.balanceOf(users.bob), POOL_1);
        assertEq(pre - post, POOL_1);
    }

    function testWithdrawWithDepositWithNoRecipient() public {
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        addLiquidityToPool(users.bob, address(token0), address(token1), true, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);
        assertEq(stakingRewards.balanceOf(users.bob), POOL_1);

        skip(1 hours);

        uint256 pre = pool.balanceOf(users.alice);
        vm.expectEmit(true, true, true, true, address(stakingRewards));
        emit IStakingRewards.Withdraw(users.alice, POOL_1);
        vm.startPrank(users.alice);
        stakingRewards.withdraw(POOL_1);
        uint256 post = pool.balanceOf(users.alice);

        assertEq(stakingRewards.totalSupply(), POOL_1);
        assertEq(stakingRewards.earned(users.alice), 0);
        assertEq(stakingRewards.balanceOf(users.alice), 0);
        assertEq(post - pre, POOL_1);

        skip(1 hours);

        pre = pool.balanceOf(users.bob);
        vm.expectEmit(true, true, true, true, address(stakingRewards));
        emit IStakingRewards.Withdraw(users.bob, POOL_1);
        vm.startPrank(users.bob);
        stakingRewards.withdraw(POOL_1);
        post = pool.balanceOf(users.bob);

        assertEq(stakingRewards.totalSupply(), 0);
        assertEq(stakingRewards.earned(users.bob), 0);
        assertEq(stakingRewards.balanceOf(users.bob), 0);
        assertEq(post - pre, POOL_1);
    }

    function testWithdrawWithDepositWithRecipient() public {
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        addLiquidityToPool(users.bob, address(token0), address(token1), true, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1, users.owner);
        assertEq(stakingRewards.balanceOf(users.bob), 0);
        assertEq(stakingRewards.balanceOf(users.owner), POOL_1);

        skip(1 hours);

        uint256 pre = pool.balanceOf(users.alice);
        vm.expectEmit(true, true, true, true, address(stakingRewards));
        emit IStakingRewards.Withdraw(users.alice, POOL_1);
        vm.startPrank(users.alice);
        stakingRewards.withdraw(POOL_1);
        uint256 post = pool.balanceOf(users.alice);

        assertEq(stakingRewards.totalSupply(), POOL_1);
        assertEq(stakingRewards.earned(users.alice), 0);
        assertEq(stakingRewards.balanceOf(users.alice), 0);
        assertEq(post - pre, POOL_1);

        skip(1 hours);

        pre = pool.balanceOf(users.owner);
        vm.expectEmit(true, true, true, true, address(stakingRewards));
        emit IStakingRewards.Withdraw(users.owner, POOL_1);
        vm.startPrank(users.owner);
        stakingRewards.withdraw(POOL_1);
        post = pool.balanceOf(users.owner);

        assertEq(stakingRewards.totalSupply(), 0);
        assertEq(stakingRewards.earned(users.owner), 0);
        assertEq(stakingRewards.balanceOf(users.owner), 0);
        assertEq(post - pre, POOL_1);
    }

    function testGetRewardWithMultipleDepositors() public {
        // add deposits
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        addLiquidityToPool(users.bob, address(token0), address(token1), true, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(stakingRewards), reward);

        skip(1 weeks / 2);

        assertApproxEqAbs(stakingRewards.earned(users.alice), reward / 4, 1e6);
        assertApproxEqAbs(stakingRewards.earned(users.bob), reward / 4, 1e6);

        vm.startPrank(users.alice);
        uint256 pre = rewardToken.balanceOf(users.alice);
        stakingRewards.getReward(users.alice);
        uint256 post = rewardToken.balanceOf(users.alice);

        assertApproxEqRel(post - pre, reward / 4, 1e6);

        skip(1 weeks / 2);

        assertApproxEqAbs(stakingRewards.earned(users.alice), reward / 4, 1e6);
        assertApproxEqAbs(stakingRewards.earned(users.bob), reward / 2, 1e6);

        pre = rewardToken.balanceOf(users.alice);
        stakingRewards.getReward(users.alice);
        post = rewardToken.balanceOf(users.alice);

        assertApproxEqRel(post - pre, reward / 4, 1e6);

        vm.startPrank(users.bob);
        pre = rewardToken.balanceOf(users.bob);
        stakingRewards.getReward(users.bob);
        post = rewardToken.balanceOf(users.bob);

        assertApproxEqRel(post - pre, reward / 2, 1e6);
    }

    function testGetRewardWithMultipleDepositorsAndEarlyWithdrawal() public {
        // add deposits
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        addLiquidityToPool(users.bob, address(token0), address(token1), true, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(stakingRewards), reward);

        skip(1 weeks / 2);

        assertApproxEqRel(stakingRewards.earned(users.alice), reward / 4, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), reward / 4, 1e6);

        uint256 pre = rewardToken.balanceOf(users.alice);
        vm.startPrank(users.alice);
        stakingRewards.getReward(users.alice);
        uint256 post = rewardToken.balanceOf(users.alice);

        assertApproxEqRel(post - pre, reward / 4, 1e6);

        // users.alice withdraws early after claiming
        stakingRewards.withdraw(POOL_1);

        skip(1 weeks / 2);

        // reward / 2 left to be disbursed to users.bob over the remainder of the week
        assertApproxEqRel(stakingRewards.earned(users.alice), 0, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), (3 * reward) / 4, 1e6);

        pre = rewardToken.balanceOf(users.bob);
        vm.startPrank(users.bob);
        stakingRewards.getReward(users.bob);
        post = rewardToken.balanceOf(users.bob);

        assertApproxEqRel(post - pre, (3 * reward) / 4, 1e6);
    }

    function testEarnedWithStaggeredDepositsAndWithdrawals() public {
        // add deposits
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(stakingRewards), reward);

        skip(1 days);

        vm.startPrank(users.alice);
        // single deposit, 1/7th of epoch
        assertApproxEqRel(stakingRewards.earned(users.alice), reward / 7, 1e6);
        stakingRewards.getReward(users.alice);

        addLiquidityToPool(users.bob, address(token0), address(token1), true, TOKEN_1, USDC_1);
        vm.startPrank(users.bob);
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        skip(1 days);
        // two deposits, equal in size, 1/7th of epoch
        uint256 expectedReward = reward / 7 / 2;
        assertApproxEqRel(stakingRewards.earned(users.alice), expectedReward, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), expectedReward, 1e6);
        vm.startPrank(users.alice);
        stakingRewards.getReward(users.alice);
        vm.startPrank(users.bob);
        stakingRewards.getReward(users.bob);

        vm.startPrank(users.alice);
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        skip(1 days);
        // two deposits, users.alice with twice the size of users.bob, 1/7th of epoch
        expectedReward = reward / 7 / 3;
        assertApproxEqRel(stakingRewards.earned(users.alice), expectedReward * 2, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), expectedReward, 1e6);
        stakingRewards.getReward(users.alice);
        vm.startPrank(users.bob);
        stakingRewards.getReward(users.bob);

        stakingRewards.withdraw(POOL_1 / 2);

        skip(1 days);
        // two deposits, users.alice with four times the size of users.bob, 1/7th of epoch
        expectedReward = reward / 7 / 5;
        assertApproxEqRel(stakingRewards.earned(users.alice), expectedReward * 4, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), expectedReward, 1e6);
    }

    function testEarnedWithStaggeredDepositsAndWithdrawalsWithoutIntermediateClaims() public {
        // add deposits
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(stakingRewards), reward);

        skip(1 days);

        vm.startPrank(users.alice);
        // single deposit, 1/7th of epoch
        uint256 ownerBal = reward / 7;
        assertApproxEqRel(stakingRewards.earned(users.alice), reward / 7, 1e6);

        addLiquidityToPool(users.bob, address(token0), address(token1), true, TOKEN_1, USDC_1);
        vm.startPrank(users.bob);
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        skip(1 days);
        // two deposits, equal in size, 1/7th of epoch
        ownerBal += (reward / 7) / 2;
        uint256 owner2Bal = (reward / 7) / 2;
        assertApproxEqRel(stakingRewards.earned(users.alice), ownerBal, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), owner2Bal, 1e6);

        vm.startPrank(users.alice);
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        skip(1 days);
        // two deposits, users.alice with twice the size of users.bob, 1/7th of epoch
        ownerBal += ((reward / 7) / 3) * 2;
        owner2Bal += (reward / 7) / 3;
        assertApproxEqRel(stakingRewards.earned(users.alice), ownerBal, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), owner2Bal, 1e6);

        vm.startPrank(users.bob);
        stakingRewards.withdraw(POOL_1 / 2);

        skip(1 days);
        // two deposits, users.alice with four times the size of users.bob, 1/7th of epoch
        ownerBal += ((reward / 7) / 5) * 4;
        owner2Bal += (reward / 7) / 5;
        assertApproxEqRel(stakingRewards.earned(users.alice), ownerBal, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), owner2Bal, 1e6);
    }

    function testGetRewardWithLateRewards() public {
        // add deposits
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        addLiquidityToPool(users.bob, address(token0), address(token1), true, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        skip(1 weeks / 2);

        // reward added late in epoch
        uint256 reward = TOKEN_1;
        addRewardToGauge(address(stakingRewards), reward);
        uint256 expectedRewardRate = reward / (WEEK / 2);
        assertApproxEqRel(stakingRewards.rewardRate(), expectedRewardRate, 1e6);

        skipToNextEpoch(0);
        // half the epoch has passed, all rewards distributed
        uint256 expectedReward = reward / 2;
        assertApproxEqRel(stakingRewards.earned(users.alice), expectedReward, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), expectedReward, 1e6);
        vm.startPrank(users.alice);
        stakingRewards.getReward(users.alice);
        assertEq(stakingRewards.earned(users.alice), 0);

        skip(1 days);
        uint256 reward2 = TOKEN_1 * 2;
        expectedRewardRate = reward2 / (6 days);
        addRewardToGauge(address(stakingRewards), reward2);
        assertApproxEqRel(stakingRewards.rewardRate(), expectedRewardRate, 1e6);

        skip(1 days);
        assertApproxEqRel(stakingRewards.earned(users.alice), reward2 / 2 / 6, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), reward / 2 + reward2 / 2 / 6, 1e6);

        skipToNextEpoch(0);
        assertApproxEqRel(stakingRewards.earned(users.alice), reward2 / 2, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), (reward + reward2) / 2, 1e6);

        uint256 pre = rewardToken.balanceOf(users.alice);
        vm.startPrank(users.alice);
        stakingRewards.getReward(users.alice);
        uint256 post = rewardToken.balanceOf(users.alice);
        assertApproxEqRel(post - pre, reward2 / 2, 1e6);

        pre = rewardToken.balanceOf(users.bob);
        vm.startPrank(users.bob);
        stakingRewards.getReward(users.bob);
        post = rewardToken.balanceOf(users.bob);

        assertApproxEqRel(post - pre, (reward + reward2) / 2, 1e6);
    }

    function testGetRewardWithNonOverlappingRewards() public {
        // add deposits
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        addLiquidityToPool(users.bob, address(token0), address(token1), true, TOKEN_1, USDC_1);

        vm.startPrank(users.bob);
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(stakingRewards), reward);
        uint256 expectedRewardRate = TOKEN_1 / WEEK;
        assertApproxEqRel(stakingRewards.rewardRate(), expectedRewardRate, 1e6);

        skipToNextEpoch(0);
        uint256 expectedReward = reward / 2;
        assertApproxEqRel(stakingRewards.earned(users.alice), expectedReward, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), expectedReward, 1e6);

        skip(1 days); // rewards distributed over 6 days intead of 7
        uint256 reward2 = TOKEN_1 * 2;
        addRewardToGauge(address(stakingRewards), reward2);
        expectedRewardRate = reward2 / (6 days);
        assertApproxEqRel(stakingRewards.rewardRate(), expectedRewardRate, 1e6);

        skip(1 days); // accrue 1/6 th of remaining rewards
        expectedReward = reward / 2 + reward2 / 2 / 6;
        assertApproxEqRel(stakingRewards.earned(users.alice), expectedReward, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), expectedReward, 1e6);

        skipToNextEpoch(0); // accrue all of remaining rewards
        expectedReward = (reward + reward2) / 2;
        assertApproxEqRel(stakingRewards.earned(users.alice), expectedReward, 1e6);
        assertApproxEqRel(stakingRewards.earned(users.bob), expectedReward, 1e6);
    }

    // function testNotifyRewardAmountWithNonZeroAmount() public {
    //     uint256 reward = TOKEN_1;
    //     deal(address(rewardToken), address(voter), reward);
    //     vm.startPrank(address(voter));
    //     rewardToken.approve(address(stakingRewards), reward);
    //     vm.expectCall(stakingRewards(stakingRewards).stakingToken(), abi.encodeCall(IPool.claimFees, ()), 1);
    //     stakingRewards(stakingRewards).notifyRewardAmount(reward);
    //     vm.stopPrank();

    //     uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
    //     assertApproxEqRel(stakingRewards.rewardRate(), reward / WEEK, 1e6);
    //     assertApproxEqRel(stakingRewards.rewardRateByEpoch(epochStart), reward / WEEK, 1e6);
    //     assertEq(rewardToken.balanceOf(address(stakingRewards)), TOKEN_1);
    //     assertEq(stakingRewards.lastUpdateTime(), block.timestamp);
    //     assertEq(stakingRewards.periodFinish(), VelodromeTimeLibrary.epochStart(block.timestamp) + WEEK);
    // }

    // function testNotifyRewardAmountWithNonZeroAmountOneDayAfterEpochFlip() public {
    //     skipAndRoll(1 days);

    //     uint256 reward = TOKEN_1;
    //     deal(address(rewardToken), address(voter), reward);
    //     vm.startPrank(address(voter));
    //     rewardToken.approve(address(stakingRewards), reward);
    //     vm.expectCall(stakingRewards(stakingRewards).stakingToken(), abi.encodeCall(IPool.claimFees, ()), 1);
    //     stakingRewards(stakingRewards).notifyRewardAmount(reward);
    //     vm.stopPrank();

    //     uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
    //     assertApproxEqRel(stakingRewards.rewardRate(), (reward / (6 days)), 1e6);
    //     assertApproxEqRel(stakingRewards.rewardRateByEpoch(epochStart), reward / (6 days), 1e6);
    //     assertEq(rewardToken.balanceOf(address(stakingRewards)), TOKEN_1);
    //     assertEq(stakingRewards.lastUpdateTime(), block.timestamp);
    //     assertEq(stakingRewards.periodFinish(), VelodromeTimeLibrary.epochStart(block.timestamp) + WEEK);
    // }

    // function testCannotNotifyRewardAmountWithZeroAmount() public {
    //     vm.prank(address(voter));
    //     vm.expectRevert(IGauge.ZeroAmount.selector);
    //     stakingRewards.notifyRewardAmount(0);
    // }

    // function testCannotNotifyRewardAmountIfNotVoter() public {
    //     vm.expectRevert(IGauge.NotVoter.selector);
    //     stakingRewards.notifyRewardAmount(TOKEN_1);
    // }

    function testCannotGetRewardIfNotOwner() public {
        // add deposits
        pool.approve(address(stakingRewards), POOL_1);
        stakingRewards.deposit(POOL_1);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(stakingRewards), reward);
        vm.stopPrank();

        vm.expectRevert(IGauge.NotAuthorized.selector);
        vm.prank(address(users.charlie));
        stakingRewards.getReward(users.alice);

        skip(1 days);

        uint256 pre = rewardToken.balanceOf(users.alice);
        vm.prank(users.alice);
        stakingRewards.getReward(users.alice);
        uint256 post = rewardToken.balanceOf(users.alice);

        assertApproxEqRel(post - pre, reward / 7, 1e6);
    }
}
