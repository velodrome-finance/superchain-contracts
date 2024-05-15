// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import "../StakingRewardsFactory.t.sol";

contract KillStakingRewardsTest is StakingRewardsFactoryTest {
    address public pool;
    address public stakingRewards;

    function setUp() public override {
        super.setUp();

        pool = poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true});
        stakingRewards = stakingRewardsFactory.createStakingRewards({_pool: pool});
    }

    function test_WhenCallerIsNotAdmin() external {
        // It should revert with NotAdmin
        vm.prank(users.charlie);
        vm.expectRevert(IStakingRewardsFactory.NotAdmin.selector);
        stakingRewardsFactory.killStakingRewards({_gauge: stakingRewards});
    }

    modifier whenCallerIsAdmin() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenStakingRewardsAlreadyKilled() external whenCallerIsAdmin {
        // It should revert with StakingRewardsAlreadyKilled
        stakingRewardsFactory.killStakingRewards({_gauge: stakingRewards});

        vm.expectRevert(IStakingRewardsFactory.StakingRewardsAlreadyKilled.selector);
        stakingRewardsFactory.killStakingRewards({_gauge: stakingRewards});
    }

    function test_WhenStakingRewardsNotKilled() external whenCallerIsAdmin {
        // It should set isAlive to false
        // It should emit {StakingRewardsKilled}
        vm.expectEmit(address(stakingRewardsFactory));
        emit IStakingRewardsFactory.StakingRewardsKilled({_gauge: stakingRewards});
        stakingRewardsFactory.killStakingRewards({_gauge: stakingRewards});

        assertFalse(stakingRewardsFactory.isAlive(stakingRewards));
    }
}
