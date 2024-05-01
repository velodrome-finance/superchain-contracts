// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../StakingRewardsFactory.t.sol";

contract ApproveKeeperTest is StakingRewardsFactoryTest {
    function test_ApproveKeeper() public {
        assertFalse(stakingRewardsFactory.isKeeper(users.alice));
        assertFalse(stakingRewardsFactory.isKeeper(users.bob));

        vm.expectEmit(true, true, true, true, address(stakingRewardsFactory));
        emit IStakingRewardsFactory.ApproveKeeper(users.alice);
        stakingRewardsFactory.approveKeeper(users.alice);
        assertTrue(stakingRewardsFactory.isKeeper(users.alice));

        assertEq(stakingRewardsFactory.keepersLength(), 1);
        assertEq(stakingRewardsFactory.keepers()[0], users.alice);

        vm.expectEmit(true, true, true, true, address(stakingRewardsFactory));
        emit IStakingRewardsFactory.ApproveKeeper(users.bob);
        stakingRewardsFactory.approveKeeper(users.bob);
        assertTrue(stakingRewardsFactory.isKeeper(users.bob));

        assertEq(stakingRewardsFactory.keepersLength(), 2);
        address[] memory relayKeepers = stakingRewardsFactory.keepers();
        assertEq(relayKeepers[0], users.alice);
        assertEq(relayKeepers[1], users.bob);
    }

    function test_RevertIf_ApproveKeeperIfNotOwner() public {
        assertFalse(stakingRewardsFactory.isKeeper(users.alice));
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        stakingRewardsFactory.approveKeeper(users.alice);
        assertEq(stakingRewardsFactory.keepersLength(), 0);
        assertFalse(stakingRewardsFactory.isKeeper(users.alice));
    }

    function test_RevertIf_ApproveKeeperIfZeroAddress() public {
        assertFalse(stakingRewardsFactory.isKeeper(users.alice));
        vm.expectRevert(IStakingRewardsFactory.ZeroAddress.selector);
        stakingRewardsFactory.approveKeeper(address(0));
        assertEq(stakingRewardsFactory.keepersLength(), 0);
        assertFalse(stakingRewardsFactory.isKeeper(users.alice));
    }

    function test_RevertIf_ApproveKeeperIfAlreadyApproved() public {
        assertFalse(stakingRewardsFactory.isKeeper(users.alice));
        vm.expectEmit(true, true, true, true, address(stakingRewardsFactory));
        emit IStakingRewardsFactory.ApproveKeeper(users.alice);
        stakingRewardsFactory.approveKeeper(users.alice);
        assertEq(stakingRewardsFactory.keepersLength(), 1);
        assertTrue(stakingRewardsFactory.isKeeper(users.alice));

        vm.expectRevert(IStakingRewardsFactory.AlreadyApproved.selector);
        stakingRewardsFactory.approveKeeper(users.alice);
        assertEq(stakingRewardsFactory.keepersLength(), 1);
        assertTrue(stakingRewardsFactory.isKeeper(users.alice));
    }
}
