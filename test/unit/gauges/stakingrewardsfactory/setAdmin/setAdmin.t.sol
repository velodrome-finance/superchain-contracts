// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../StakingRewardsFactory.t.sol";

contract SetAdminTest is StakingRewardsFactoryTest {
    function test_WhenCallerIsNotAdmin() external {
        // It should revert with NotAdmin
        vm.prank(users.charlie);
        vm.expectRevert(IStakingRewardsFactory.NotAdmin.selector);
        stakingRewardsFactory.setAdmin({_admin: users.charlie});
    }

    modifier whenCallerIsAdmin() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenAdminIsTheZeroAddress() external whenCallerIsAdmin {
        // It should revert with ZeroAddress
        vm.expectRevert(IStakingRewardsFactory.ZeroAddress.selector);
        stakingRewardsFactory.setAdmin({_admin: address(0)});
    }

    function test_WhenAdminIsNotTheZeroAddress() external whenCallerIsAdmin {
        // It should set the new admin
        // It should emit a {SetAdmin} event
        assertEq(stakingRewardsFactory.admin(), users.owner);

        vm.expectEmit(true, true, true, true, address(stakingRewardsFactory));
        emit IStakingRewardsFactory.SetAdmin({_admin: users.bob});
        stakingRewardsFactory.setAdmin({_admin: users.bob});

        assertEq(stakingRewardsFactory.admin(), users.bob);
    }
}
