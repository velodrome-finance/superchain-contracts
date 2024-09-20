// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract SetEmissionAdminIntegrationConcreteTest is RootGaugeFactoryTest {
    function test_WhenCallerIsNotTheEmissionAdmin() external {
        // It should revert with {NotAuthorized}
        vm.prank(users.charlie);
        vm.expectRevert(IRootGaugeFactory.NotAuthorized.selector);
        rootGaugeFactory.setEmissionAdmin({_admin: users.charlie});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.prank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function test_WhenAdminIsTheZeroAddress() external whenCallerIsTheEmissionAdmin {
        // It should revert with {ZeroAddress}
        vm.expectRevert(IRootGaugeFactory.ZeroAddress.selector);
        rootGaugeFactory.setEmissionAdmin({_admin: address(0)});
    }

    function test_WhenAdminIsNotTheZeroAddress() external whenCallerIsTheEmissionAdmin {
        // It should set the new emission admin
        // It should emit a {SetEmissionAdmin} event
        vm.expectEmit(address(rootGaugeFactory));
        emit IRootGaugeFactory.SetEmissionAdmin({_emissionAdmin: users.alice});
        rootGaugeFactory.setEmissionAdmin({_admin: users.alice});

        assertEq(rootGaugeFactory.emissionAdmin(), users.alice);
    }
}
