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

    modifier whenDefaultCapIsNotZero() {
        vm.expectEmit(address(rootGaugeFactory));
        emit IRootGaugeFactory.DefaultCapSet({_newDefaultCap: 1000});
        rootGaugeFactory.setDefaultCap({_defaultCap: 1000});
        _;
    }

    function test_WhenDefaultCapIsGreaterThanMaxBps() external whenCallerIsTheEmissionAdmin whenDefaultCapIsNotZero {
        // It should revert with {MaximumCapExceeded}
        vm.expectRevert(IRootGaugeFactory.MaximumCapExceeded.selector);
        rootGaugeFactory.setDefaultCap({_defaultCap: 10_001});
    }

    function test_WhenDefaultCapIsLessOrEqualToMaxBps() external whenCallerIsTheEmissionAdmin whenDefaultCapIsNotZero {
        // It should set the new default cap for gauges
        // It should emit a {DefaultCapSet} event
        vm.expectEmit(address(rootGaugeFactory));
        emit IRootGaugeFactory.DefaultCapSet({_newDefaultCap: 1000});
        rootGaugeFactory.setDefaultCap({_defaultCap: 1000});

        assertEq(rootGaugeFactory.defaultCap(), 1000);
    }

    function testGas_setDefaultCap() external whenCallerIsTheEmissionAdmin {
        rootGaugeFactory.setDefaultCap({_defaultCap: 1000});
        vm.snapshotGasLastCall("RootGaugeFactory_setDefaultCap");
    }
}
