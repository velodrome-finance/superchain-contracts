// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafGaugeFactory.t.sol";

contract SetNotifyAdminIntegrationFuzzTest is LeafGaugeFactoryTest {
    function testFuzz_WhenCallerIsNotTheNotifyAdmin(address _caller) external {
        vm.assume(_caller != leafGaugeFactory.notifyAdmin());
        // It should revert with NotAuthorized
        vm.prank(_caller);
        vm.expectRevert(ILeafGaugeFactory.NotAuthorized.selector);
        leafGaugeFactory.setNotifyAdmin({_admin: _caller});
    }

    modifier whenCallerIsTheNotifyAdmin() {
        vm.prank(leafGaugeFactory.notifyAdmin());
        _;
    }

    function testFuzz_WhenAdminIsNotTheZeroAddress(address _notifyAdmin) external whenCallerIsTheNotifyAdmin {
        vm.assume(_notifyAdmin != address(0));
        // It should set the new notify admin
        // It should emit a {SetNotifyAdmin} event
        vm.expectEmit(address(leafGaugeFactory));
        emit ILeafGaugeFactory.SetNotifyAdmin({notifyAdmin: _notifyAdmin});
        leafGaugeFactory.setNotifyAdmin({_admin: _notifyAdmin});

        assertEq(leafGaugeFactory.notifyAdmin(), _notifyAdmin);
    }
}
