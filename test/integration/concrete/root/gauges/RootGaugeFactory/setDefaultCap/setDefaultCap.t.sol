// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract SetDefaultCapIntegrationConcreteTest is RootGaugeFactoryTest {
    function test_WhenCallerIsNotTheEmissionAdmin() external {
        // It should revert with {NotAuthorized}
        vm.prank(users.charlie);
        vm.expectRevert(IRootGaugeFactory.NotAuthorized.selector);
        rootGaugeFactory.setDefaultCap({_defaultCap: 1000});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.startPrank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function test_WhenDefaultCapIsZero() external whenCallerIsTheEmissionAdmin {
        // It should revert with {ZeroDefaultCap}
        vm.expectRevert(IRootGaugeFactory.ZeroDefaultCap.selector);
        rootGaugeFactory.setDefaultCap({_defaultCap: 0});
    }

    function test_WhenDefaultCapIsNotZero() external whenCallerIsTheEmissionAdmin {
        // It should set the new default cap for gauges
        // It should emit a {SetDefaultCap} event
        vm.expectEmit(address(rootGaugeFactory));
        emit IRootGaugeFactory.SetDefaultCap({_newDefaultCap: 1000});
        rootGaugeFactory.setDefaultCap({_defaultCap: 1000});

        assertEq(rootGaugeFactory.defaultCap(), 1000);
    }
}
