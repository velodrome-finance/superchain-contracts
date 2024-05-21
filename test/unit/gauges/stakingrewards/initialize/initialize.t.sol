// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../stakingRewardsBase.t.sol";

contract InitializeTest is StakingRewardsBaseTest {
    function setUp() public virtual override {
        super.setUp();

        changePrank(address(stakingRewardsFactory));
    }

    function test_WhenFactoryIsAlreadySet() external {
        // It should revert with FactoryAlreadySet
        vm.expectRevert(IStakingRewards.FactoryAlreadySet.selector);
        stakingRewards.initialize(address(pool), address(rewardToken));
    }

    function test_WhenFactoryIsNotSet() external {
        // It should set the factory
        // It should set the staking token
        // It should set the reward token
        // It should set the fee converter
        stakingRewards = new StakingRewards();

        stakingRewards.initialize(address(pool), address(rewardToken));

        assertEq(stakingRewards.factory(), address(stakingRewardsFactory));
        assertEq(stakingRewards.stakingToken(), address(pool));
        assertEq(stakingRewards.rewardToken(), address(rewardToken));
        assertNotEq(stakingRewards.feeConverter(), address(0));
    }
}
