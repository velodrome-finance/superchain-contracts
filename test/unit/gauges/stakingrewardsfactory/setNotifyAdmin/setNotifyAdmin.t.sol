// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../StakingRewardsFactory.t.sol";

contract SetNotifyAdminTest is StakingRewardsFactoryTest {
    function test_WhenTheCallerIsNotTheNotifyAdmin() external {
        // It should revert with NotNotifyAdmin
        vm.prank(users.charlie);
        vm.expectRevert(IStakingRewardsFactory.NotNotifyAdmin.selector);
        stakingRewardsFactory.setNotifyAdmin({_notifyAdmin: users.charlie});
    }

    modifier whenTheCallerIsTheNotifyAdmin() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenAdminIsTheZeroAddress() external whenTheCallerIsTheNotifyAdmin {
        // It should revert with ZeroAddress
        vm.expectRevert(IStakingRewardsFactory.ZeroAddress.selector);
        stakingRewardsFactory.setNotifyAdmin({_notifyAdmin: address(0)});
    }

    function test_WhenAdminIsNotTheZeroAddress() external whenTheCallerIsTheNotifyAdmin {
        // It should set the new notify admin
        // It should emit a {SetNotifyAdmin} event
        assertEq(stakingRewardsFactory.notifyAdmin(), users.owner);

        vm.expectEmit(true, true, true, true, address(stakingRewardsFactory));
        emit IStakingRewardsFactory.SetNotifyAdmin({_notifyAdmin: users.bob});
        stakingRewardsFactory.setNotifyAdmin({_notifyAdmin: users.bob});

        assertEq(stakingRewardsFactory.notifyAdmin(), users.bob);
    }
}
