// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../stakingRewardsBase.t.sol";

contract DepositTest is StakingRewardsBaseTest {
    function test_WhenTheAmountIsZero() external {
        // It should revert with ZeroAmount
        vm.expectRevert(IGauge.ZeroAmount.selector);
        stakingRewards.deposit(0);
    }

    function test_WhenTheAmountIsNotZero() external {
        assertEq(stakingRewards.totalSupply(), 0);

        IERC20 stakingToken = IERC20(stakingRewards.stakingToken());

        uint256 preBalanceStakingToken = stakingToken.balanceOf(address(stakingRewards));

        uint256 pre = pool.balanceOf(users.alice);
        pool.approve(address(stakingRewards), POOL_1);

        // It should emit {Deposit} event
        vm.expectEmit(true, true, true, true, address(stakingRewards));
        emit IStakingRewards.Deposit(users.alice, users.alice, POOL_1);

        stakingRewards.deposit(POOL_1);

        uint256 post = pool.balanceOf(users.alice);

        // It should add amount to totalSupply
        assertEq(stakingRewards.totalSupply(), POOL_1);
        // It should add amount to balanceOf[caller]
        assertEq(pre - post, POOL_1);
        // It should set rewardPerTokenStored
        assertEq(stakingRewards.rewardPerTokenStored(), stakingRewards.rewardPerToken());
        // It should set lastUpdateTime
        assertEq(stakingRewards.lastUpdateTime(), stakingRewards.lastTimeRewardApplicable());
        // It should set rewards[_account]
        assertEq(stakingRewards.rewards(users.alice), stakingRewards.earned(users.alice));
        // It should set userRewardPerTokenPaid[_account]
        assertEq(stakingRewards.userRewardPerTokenPaid(users.alice), stakingRewards.rewardPerTokenStored());
        // It should transfer the amount
        assertEq(stakingToken.balanceOf(address(stakingRewards)), preBalanceStakingToken + POOL_1);
    }
}