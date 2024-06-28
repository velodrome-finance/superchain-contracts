// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

contract NotifyRewardAmountFuzzTest is BaseFixture {
    Pool public pool;
    StakingRewards public stakingRewards;

    function setUp() public override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        stakingRewards = StakingRewards(stakingRewardsFactory.createStakingRewards({_pool: address(pool)}));

        addLiquidityToPool(users.alice, address(token0), address(token1), true, TOKEN_1, USDC_1);
        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, TOKEN_1 * 1_000_000);
        rewardToken.approve(address(stakingRewards), type(uint256).max);

        vm.startPrank(users.alice);
        pool.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.deposit(POOL_1);

        skipToNextEpoch(0);
    }

    modifier whenCallerIsNotifyAdmin() {
        vm.startPrank(users.owner);
        _;
    }

    modifier whenTheAmountIsGreaterThanZero() {
        _;
    }

    function testFuzz_WhenTheCurrentTimestampIsLessThanPeriodFinish(uint32 jump1, uint32 jump2)
        external
        whenCallerIsNotifyAdmin
        whenTheAmountIsGreaterThanZero
    {
        jump1 = uint32(bound(jump1, 0, WEEK - 1));
        jump2 = uint32(bound(jump2, 0, WEEK - 1));
        // It should update rewardPerTokenStored
        // It should transfer funds from the caller to the contract
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1000;
        skipAndRoll(jump1); // jump1 can be 0

        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.owner, amount: amount});
        stakingRewards.notifyRewardAmount({_amount: amount});

        uint256 originalRewardRate = amount / WEEK;
        assertEq(stakingRewards.rewardRate(), originalRewardRate);
        uint256 lastUpdateTime = block.timestamp;
        uint256 periodFinish = stakingRewards.periodFinish();
        skipAndRoll(jump2);

        // include rounding error in the calculation
        uint256 amount2 = TOKEN_1 * 500;
        uint256 timeUntilNext = periodFinish - block.timestamp;
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.owner, amount: amount2});
        stakingRewards.notifyRewardMatch({_amount: amount2});

        uint256 rpts = (block.timestamp - lastUpdateTime) * (amount / WEEK) * 1e18 / POOL_1;
        assertEq(stakingRewards.rewardPerTokenStored(), rpts);
        assertEq(rewardToken.balanceOf(address(stakingRewards)), amount + amount2);
        uint256 amountLeft = (amount / WEEK) * timeUntilNext; // include rounding error
        uint256 rewardRate = (amountLeft + amount2) / timeUntilNext;
        assertEq(stakingRewards.rewardRate(), rewardRate);
        assertEq(stakingRewards.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        assertEq(stakingRewards.lastUpdateTime(), block.timestamp);
        assertEq(stakingRewards.periodFinish(), periodFinish);

        skipAndRoll(periodFinish + 1); // ensure all claimable
        vm.startPrank(users.alice);
        stakingRewards.getReward(users.alice);
        assertLt(rewardToken.balanceOf(address(stakingRewards)), 1e6);
    }
}
