// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../stakingRewardsBase.t.sol";

contract WithdrawTest is StakingRewardsBaseTest {
    function setUp() public override {
        super.setUp();
        pool.approve(address(stakingRewards), POOL_1);

        stakingRewards.deposit(POOL_1);
    }

    function test_WhenTheAmountIsGreaterThanBalanceOfSender() external {
        uint256 amount = pool.balanceOf(users.alice) + 1;
        // It should revert with Math over/underflow
        vm.expectRevert();
        stakingRewards.withdraw(amount);
    }

    function test_WhenTheAmountIsEqualOrLowerThanBalanceOfSender() external {
        IERC20 stakingToken = IERC20(stakingRewards.stakingToken());
        uint256 pre = pool.balanceOf(users.alice);
        uint256 preTotalSupply = stakingRewards.totalSupply();
        uint256 preBalanceOfStakingToken = stakingToken.balanceOf(address(users.alice));

        // It should emit {Withdraw} event
        vm.expectEmit(true, true, true, true, address(stakingRewards));
        emit IStakingRewards.Withdraw(users.alice, POOL_1);

        stakingRewards.withdraw(POOL_1);
        uint256 post = pool.balanceOf(users.alice);

        // It should subtract amount from totalSupply
        assertEq(preTotalSupply - stakingRewards.totalSupply(), POOL_1);
        assertEq(stakingRewards.earned(users.alice), 0);
        // It should subtract amount from balanceOf[user]
        assertEq(stakingRewards.balanceOf(users.alice), 0);
        // It should transfer the amount
        assertEq(post - pre, POOL_1);
        assertEq(stakingToken.balanceOf(address(users.alice)), preBalanceOfStakingToken + POOL_1);

        // It should set rewardPerTokenStored
        assertEq(stakingRewards.rewardPerTokenStored(), 0);
        // It should set lastUpdateTime
        assertEq(stakingRewards.lastUpdateTime(), 0);
        // It should set rewards[user]
        assertEq(stakingRewards.rewards(users.alice), 0);
        // It should set userRewardPerTokenPaid[user]
        assertEq(stakingRewards.userRewardPerTokenPaid(users.alice), 0);
    }
}
