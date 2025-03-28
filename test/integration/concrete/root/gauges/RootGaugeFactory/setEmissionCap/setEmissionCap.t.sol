// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract SetEmissionCapIntegrationConcreteTest is RootGaugeFactoryTest {
    address gauge;

    function test_WhenCallerIsNotTheEmissionAdmin() external {
        // It should revert with {NotAuthorized}
        vm.prank(users.charlie);
        vm.expectRevert(IRootGaugeFactory.NotAuthorized.selector);
        rootGaugeFactory.setEmissionCap({_gauge: address(0), _emissionCap: 1000});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.startPrank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function test_WhenGaugeIsTheZeroAddress() external whenCallerIsTheEmissionAdmin {
        // It should revert with {ZeroAddress}
        vm.expectRevert(IRootGaugeFactory.ZeroAddress.selector);
        rootGaugeFactory.setEmissionCap({_gauge: address(0), _emissionCap: 1000});
    }

    modifier whenGaugeIsNotTheZeroAddress() {
        gauge = address(rootGauge);
        _;
    }

    function test_WhenEmissionCapIsGreaterThanMaxBps()
        external
        whenCallerIsTheEmissionAdmin
        whenGaugeIsNotTheZeroAddress
    {
        // It should revert with {MaximumCapExceeded}
        vm.expectRevert(IRootGaugeFactory.MaximumCapExceeded.selector);
        rootGaugeFactory.setEmissionCap({_gauge: gauge, _emissionCap: 10_001});
    }

    function test_WhenEmissionCapIsLessOrEqualToMaxBps()
        external
        whenCallerIsTheEmissionAdmin
        whenGaugeIsNotTheZeroAddress
    {
        // It should set the new emission cap for the gauge
        // It should emit a {EmissionCapSet} event
        assertEq(rootGaugeFactory.emissionCaps(gauge), 100);

        vm.expectEmit(address(rootGaugeFactory));
        emit IRootGaugeFactory.EmissionCapSet({_gauge: address(rootGauge), _newEmissionCap: 1000});
        rootGaugeFactory.setEmissionCap({_gauge: gauge, _emissionCap: 1000});

        assertEq(rootGaugeFactory.emissionCaps(gauge), 1000);
    }

    function testGas_setEmissionCap() external whenCallerIsTheEmissionAdmin {
        rootGaugeFactory.setEmissionCap({_gauge: address(rootGauge), _emissionCap: 1000});
        vm.snapshotGasLastCall("RootGaugeFactory_setEmissionCap");
    }
}
