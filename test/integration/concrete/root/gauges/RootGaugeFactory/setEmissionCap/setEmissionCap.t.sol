// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract SetEmissionCapIntegrationConcreteTest is RootGaugeFactoryTest {
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

    function test_WhenGaugeIsNotTheZeroAddress() external whenCallerIsTheEmissionAdmin {
        // It should set the new emission cap for the gauge
        // It should emit a {EmissionCapSet} event
        assertEq(rootGaugeFactory.emissionCaps(address(rootGauge)), 100);

        vm.expectEmit(address(rootGaugeFactory));
        emit IRootGaugeFactory.EmissionCapSet({_gauge: address(rootGauge), _newEmissionCap: 1000});
        rootGaugeFactory.setEmissionCap({_gauge: address(rootGauge), _emissionCap: 1000});

        assertEq(rootGaugeFactory.emissionCaps(address(rootGauge)), 1000);
    }

    function testGas_setEmissionCap() external whenCallerIsTheEmissionAdmin {
        rootGaugeFactory.setEmissionCap({_gauge: address(rootGauge), _emissionCap: 1000});
        snapLastCall("RootGaugeFactory_setEmissionCap");
    }
}
