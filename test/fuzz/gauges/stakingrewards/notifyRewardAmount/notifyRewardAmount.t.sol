// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../../BaseFixture.sol";

contract NotifyRewardAmountFuzzTest is BaseFixture {
    Pool public pool;
    StakingRewards public stakingRewards;

    function setUp() public override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        stakingRewards = StakingRewards(
            stakingRewardsFactory.createStakingRewards({_pool: address(pool), _rewardToken: address(rewardToken)})
        );

        addLiquidityToPool(users.alice, address(token0), address(token1), true, TOKEN_1, USDC_1);
        vm.startPrank(users.alice);
        deal(address(rewardToken), users.alice, TOKEN_1 * 1_000_000);
        rewardToken.approve(address(stakingRewards), type(uint256).max);

        pool.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.deposit(POOL_1);
        skipToNextEpoch(0);
    }

    modifier whenTheAmountIsGreaterThanTheTimeUntilTheNextTimestamp() {
        _;
    }

    function testFuzz_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish(uint32 jump1)
        external
        whenTheAmountIsGreaterThanTheTimeUntilTheNextTimestamp
    {
        jump1 = uint32(bound(jump1, 0, WEEK - 1));
        // It should update rewardPerTokenStored
        // It should transfer funds from the caller to the contract
        // It should set a new reward rate
        // It should cache the reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1;

        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: amount});
        stakingRewards.notifyRewardAmount({_amount: amount});

        skipAndRoll(WEEK); // skip one week
        skipAndRoll(jump1); // jump1 can be 0

        uint256 amount2 = TOKEN_1 * 2;
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: amount2});
        stakingRewards.notifyRewardAmount({_amount: amount2});

        uint256 rpts = WEEK * (amount / WEEK) * 1e18 / POOL_1;
        assertEq(stakingRewards.rewardPerTokenStored(), rpts);
        assertEq(rewardToken.balanceOf(address(stakingRewards)), amount + amount2);
        assertEq(stakingRewards.rewardRate(), amount2 / WEEK);
        assertEq(stakingRewards.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), amount2 / WEEK);
        assertEq(stakingRewards.lastUpdateTime(), block.timestamp);
        assertEq(stakingRewards.periodFinish(), block.timestamp + WEEK);

        skipAndRoll(block.timestamp + WEEK + 1); // ensure all claimable
        stakingRewards.getReward(users.alice);
        assertLt(rewardToken.balanceOf(address(stakingRewards)), 1e6);
    }

    function test_FuzzWhenAmountIsLessThanLeftoverRewards(uint32 jump1, uint32 jump2, uint256 amount)
        external
        whenTheAmountIsGreaterThanTheTimeUntilTheNextTimestamp
    {
        jump1 = uint32(bound(jump1, 0, WEEK - 1));
        jump2 = uint32(bound(jump2, 0, WEEK - 1));
        amount = bound(amount, TOKEN_1, TOKEN_1 * 10_000);
        // It should revert with InsufficientAmount
        skipAndRoll(jump1); // jump1 can be 0

        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: amount});
        stakingRewards.notifyRewardAmount({_amount: amount});

        uint256 originalRewardRate = amount / WEEK;
        assertEq(stakingRewards.rewardRate(), originalRewardRate);
        skipAndRoll(jump2);

        // include rounding error in the calculation
        uint256 leftover = (amount / WEEK * WEEK) * (WEEK - jump2) / WEEK;
        uint256 amount2 = bound(leftover, 1, leftover - 1);
        vm.expectRevert(IStakingRewards.InsufficientAmount.selector);
        stakingRewards.notifyRewardAmount({_amount: amount2});
    }

    function testFuzz_WhenAmountIsGreaterThanOrEqualToLeftoverRewards(uint32 jump1, uint32 jump2)
        external
        whenTheAmountIsGreaterThanTheTimeUntilTheNextTimestamp
    {
        jump1 = uint32(bound(jump1, 0, WEEK - 1));
        jump2 = uint32(bound(jump2, 0, WEEK - 1));
        // It should update rewardPerTokenStored
        // It should transfer funds from the caller to the contract
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1_000;
        skipAndRoll(jump1); // jump1 can be 0

        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: amount});
        stakingRewards.notifyRewardAmount({_amount: amount});

        uint256 originalRewardRate = amount / WEEK;
        assertEq(stakingRewards.rewardRate(), originalRewardRate);
        uint256 lastUpdateTime = block.timestamp;
        skipAndRoll(jump2);

        // include rounding error in the calculation
        uint256 amount2 = (amount / WEEK * WEEK) * (WEEK - jump2) / WEEK;
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: amount2});
        stakingRewards.notifyRewardAmount({_amount: amount2});

        uint256 rpts = (block.timestamp - lastUpdateTime) * (amount / WEEK) * 1e18 / POOL_1;
        assertEq(stakingRewards.rewardPerTokenStored(), rpts);
        assertEq(rewardToken.balanceOf(address(stakingRewards)), amount + amount2);
        uint256 amountLeft = amount / WEEK * WEEK * (WEEK - jump2) / WEEK; // include rounding error
        uint256 rewardRate = (amountLeft + amount2) / WEEK;
        assertEq(stakingRewards.rewardRate(), rewardRate);
        assertEq(stakingRewards.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        assertEq(stakingRewards.lastUpdateTime(), block.timestamp);
        assertEq(stakingRewards.periodFinish(), block.timestamp + WEEK);

        skipAndRoll(block.timestamp + WEEK + 1); // ensure all claimable
        stakingRewards.getReward(users.alice);
        assertLt(rewardToken.balanceOf(address(stakingRewards)), 1e6);
    }
}
