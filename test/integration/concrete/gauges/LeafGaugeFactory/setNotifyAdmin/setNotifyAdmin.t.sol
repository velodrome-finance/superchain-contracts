// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafGaugeFactory.t.sol";

contract SetNotifyAdminIntegrationConcreteTest is LeafGaugeFactoryTest {
    function test_WhenCallerIsNotTheNotifyAdmin() external {
        // It should revert with NotAuthorized
        vm.prank(users.charlie);
        vm.expectRevert(ILeafGaugeFactory.NotAuthorized.selector);
        leafGaugeFactory.setNotifyAdmin({_admin: users.charlie});
    }

    modifier whenCallerIsTheNotifyAdmin() {
        vm.prank(leafGaugeFactory.notifyAdmin());
        _;
    }

    function test_WhenAdminIsTheZeroAddress() external whenCallerIsTheNotifyAdmin {
        // It should revert with ZeroAddress
        vm.expectRevert(ILeafGaugeFactory.ZeroAddress.selector);
        leafGaugeFactory.setNotifyAdmin({_admin: address(0)});
    }

    function test_WhenAdminIsNotTheZeroAddress() external whenCallerIsTheNotifyAdmin {
        // It should set the new notify admin
        // It should emit a {SetNotifyAdmin} event
        vm.expectEmit(address(leafGaugeFactory));
        emit ILeafGaugeFactory.SetNotifyAdmin({notifyAdmin: users.deployer});
        leafGaugeFactory.setNotifyAdmin({_admin: users.deployer});

        assertEq(leafGaugeFactory.notifyAdmin(), users.deployer);
    }
}
