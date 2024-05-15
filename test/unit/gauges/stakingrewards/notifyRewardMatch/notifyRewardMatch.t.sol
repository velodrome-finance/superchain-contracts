// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../../BaseFixture.sol";

contract NotifyRewardMatchTest is BaseFixture {
    Pool public pool;
    StakingRewards public stakingRewards;

    uint256 public constant amount = TOKEN_1 * 10;

    function setUp() public override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        stakingRewards = StakingRewards(stakingRewardsFactory.createStakingRewards({_pool: address(pool)}));

        addLiquidityToPool(users.alice, address(token0), address(token1), true, TOKEN_1, USDC_1);
        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, TOKEN_1 * 1_000_000);
        rewardToken.approve(address(stakingRewards), type(uint256).max);

        stakingRewards.notifyRewardAmount({_amount: amount});
    }

    function test_WhenCallerIsNotNotifyAdmin() external {
        // It should revert with NotNotifyAdmin
        vm.startPrank(users.charlie);
        vm.expectRevert(IStakingRewards.NotNotifyAdmin.selector);
        stakingRewards.notifyRewardMatch({_amount: 1});
    }

    modifier whenCallerIsNotifyAdmin() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenAmountIsZero() external whenCallerIsNotifyAdmin {
        // It should revert with ZeroAmount
        vm.expectRevert(IStakingRewards.ZeroAmount.selector);
        stakingRewards.notifyRewardMatch({_amount: 0});
    }

    modifier whenTheAmountIsGreaterThanZero() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish()
        external
        whenCallerIsNotifyAdmin
        whenTheAmountIsGreaterThanZero
    {
        // It should revert with PeriodFinish
        skipAndRoll(1 weeks);
        vm.expectRevert(IStakingRewards.PeriodFinish.selector);
        stakingRewards.notifyRewardMatch({_amount: WEEK});
    }

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish()
        external
        whenCallerIsNotifyAdmin
        whenTheAmountIsGreaterThanZero
    {
        // It should update rewardPerTokenStored
        // It should transfer funds from the caller to the contract
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should emit a {NotifyReward} event
        skipAndRoll(2 days);
        uint256 amount2 = TOKEN_1 * 20;
        uint256 periodFinish = stakingRewards.periodFinish();
        uint256 timeUntilNext = periodFinish - block.timestamp;
        stakingRewards.notifyRewardMatch({_amount: amount2});

        assertEq(stakingRewards.rewardPerTokenStored(), 0);
        assertEq(rewardToken.balanceOf(address(stakingRewards)), amount + amount2);
        assertEq(stakingRewards.rewardRate(), (amount * 5 / 7 + amount2) / timeUntilNext);
        assertEq(stakingRewards.rewardRateByEpoch(604800), (amount * 5 / 7 + amount2) / timeUntilNext);
        assertEq(stakingRewards.lastUpdateTime(), block.timestamp);
        assertEq(stakingRewards.periodFinish(), periodFinish);
    }
}
