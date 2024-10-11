// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract SetNotifyAdminIntegrationFuzzTest is RootGaugeFactoryTest {
    function testFuzz_WhenCallerIsNotTheNotifyAdmin(address _caller) external {
        vm.assume(_caller != rootGaugeFactory.notifyAdmin());
        // It should revert with {NotAuthorized}
        vm.prank(_caller);
        vm.expectRevert(IRootGaugeFactory.NotAuthorized.selector);
        rootGaugeFactory.setNotifyAdmin({_admin: _caller});
    }

    modifier whenCallerIsTheNotifyAdmin() {
        vm.prank(rootGaugeFactory.notifyAdmin());
        _;
    }

    function testFuzz_WhenAdminIsNotTheZeroAddress(address _notifyAdmin) external whenCallerIsTheNotifyAdmin {
        vm.assume(_notifyAdmin != address(0));
        // It should set the new notify admin
        // It should emit a {SetNotifyAdmin} event
        vm.expectEmit(address(rootGaugeFactory));
        emit IRootGaugeFactory.SetNotifyAdmin({notifyAdmin: _notifyAdmin});
        rootGaugeFactory.setNotifyAdmin({_admin: _notifyAdmin});

        assertEq(rootGaugeFactory.notifyAdmin(), _notifyAdmin);
    }
}
