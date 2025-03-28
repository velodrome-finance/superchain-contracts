// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract SetNotifyAdminIntegrationConcreteTest is RootGaugeFactoryTest {
    function test_WhenCallerIsNotTheNotifyAdmin() external {
        // It should revert with {NotAuthorized}
        vm.prank(users.charlie);
        vm.expectRevert(IRootGaugeFactory.NotAuthorized.selector);
        rootGaugeFactory.setNotifyAdmin({_admin: users.charlie});
    }

    modifier whenCallerIsTheNotifyAdmin() {
        vm.prank(rootGaugeFactory.notifyAdmin());
        _;
    }

    function test_WhenAdminIsTheZeroAddress() external whenCallerIsTheNotifyAdmin {
        // It should revert with {ZeroAddress}
        vm.expectRevert(IRootGaugeFactory.ZeroAddress.selector);
        rootGaugeFactory.setNotifyAdmin({_admin: address(0)});
    }

    function test_WhenAdminIsNotTheZeroAddress() external whenCallerIsTheNotifyAdmin {
        // It should set the new notify admin
        // It should emit a {NotifyAdminSet} event
        vm.expectEmit(address(rootGaugeFactory));
        emit IRootGaugeFactory.NotifyAdminSet({notifyAdmin: users.alice});
        rootGaugeFactory.setNotifyAdmin({_admin: users.alice});

        assertEq(rootGaugeFactory.notifyAdmin(), users.alice);
    }

    function testGas_setNotifyAdmin() external whenCallerIsTheNotifyAdmin {
        rootGaugeFactory.setNotifyAdmin({_admin: users.alice});
        vm.snapshotGasLastCall("RootGaugeFactory_setNotifyAdmin");
    }
}
