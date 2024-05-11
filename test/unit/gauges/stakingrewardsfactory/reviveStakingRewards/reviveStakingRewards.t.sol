// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import "../StakingRewardsFactory.t.sol";

contract ReviveStakingRewardsTest is StakingRewardsFactoryTest {
    address public pool;
    address public stakingRewards;

    function setUp() public override {
        super.setUp();

        pool = poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true});
        stakingRewards = stakingRewardsFactory.createStakingRewards({_pool: pool, _rewardToken: address(rewardToken)});
    }

    function test_WhenCallerIsNotAdmin() external {
        // It should revert with NotAdmin
        vm.prank(users.charlie);
        vm.expectRevert(IStakingRewardsFactory.NotAdmin.selector);
        stakingRewardsFactory.reviveStakingRewards({_gauge: stakingRewards});
    }

    modifier whenCallerIsAdmin() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenStakingRewardsNotKilled() external whenCallerIsAdmin {
        // It should revert with StakingRewardsStillAlive
        vm.expectRevert(IStakingRewardsFactory.StakingRewardsStillAlive.selector);
        stakingRewardsFactory.reviveStakingRewards({_gauge: stakingRewards});
    }

    function test_WhenStakingRewardsKilled() external whenCallerIsAdmin {
        // It should set isAlive to true
        // It should emit {StakingRewardsRevived}
        stakingRewardsFactory.killStakingRewards({_gauge: stakingRewards});

        vm.expectEmit(address(stakingRewardsFactory));
        emit IStakingRewardsFactory.StakingRewardsRevived({_gauge: stakingRewards});
        stakingRewardsFactory.reviveStakingRewards({_gauge: stakingRewards});

        assertTrue(stakingRewardsFactory.isAlive(stakingRewards));
    }
}
