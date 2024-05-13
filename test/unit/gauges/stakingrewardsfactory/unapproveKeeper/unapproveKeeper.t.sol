// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../StakingRewardsFactory.t.sol";

contract UnapproveKeeperTest is StakingRewardsFactoryTest {
    function test_UnapproveKeeper() public {
        vm.startPrank(users.owner);
        stakingRewardsFactory.approveKeeper(users.alice);
        stakingRewardsFactory.approveKeeper(users.bob);
        assertTrue(stakingRewardsFactory.isKeeper(users.alice));
        assertTrue(stakingRewardsFactory.isKeeper(users.bob));

        assertEq(stakingRewardsFactory.keepersLength(), 2);
        address[] memory relayKeepers = stakingRewardsFactory.keepers();
        assertEq(relayKeepers[0], users.alice);
        assertEq(relayKeepers[1], users.bob);

        vm.expectEmit(true, true, true, true, address(stakingRewardsFactory));
        emit IStakingRewardsFactory.UnapproveKeeper(users.alice);
        stakingRewardsFactory.unapproveKeeper(users.alice);
        assertFalse(stakingRewardsFactory.isKeeper(users.alice));

        relayKeepers = stakingRewardsFactory.keepers();
        assertEq(relayKeepers[0], users.bob);
        assertEq(stakingRewardsFactory.keepersLength(), 1);

        vm.expectEmit(true, true, true, true, address(stakingRewardsFactory));
        emit IStakingRewardsFactory.UnapproveKeeper(users.bob);
        stakingRewardsFactory.unapproveKeeper(users.bob);
        assertFalse(stakingRewardsFactory.isKeeper(users.bob));

        assertEq(stakingRewardsFactory.keepersLength(), 0);
        relayKeepers = stakingRewardsFactory.keepers();
        assertEq(relayKeepers.length, 0);
    }

    function test_RevertIf_UnapproveKeeperIfNotApproved() public {
        vm.startPrank(users.owner);
        assertEq(stakingRewardsFactory.keepersLength(), 0);
        assertFalse(stakingRewardsFactory.isKeeper(users.alice));

        vm.expectRevert(IStakingRewardsFactory.NotApproved.selector);
        stakingRewardsFactory.unapproveKeeper(users.alice);
        assertFalse(stakingRewardsFactory.isKeeper(users.alice));
        assertEq(stakingRewardsFactory.keepersLength(), 0);
    }

    function test_RevertIf_UnapproveKeeperIfNotOwner() public {
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        stakingRewardsFactory.unapproveKeeper(users.charlie);
    }
}
