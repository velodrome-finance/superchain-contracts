// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract SetDefaultCapIntegrationFuzzTest is RootGaugeFactoryTest {
    function testFuzz_WhenCallerIsNotTheEmissionAdmin(address _caller) external {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != rootGaugeFactory.emissionAdmin());

        vm.prank(_caller);
        vm.expectRevert(IRootGaugeFactory.NotAuthorized.selector);
        rootGaugeFactory.setDefaultCap({_defaultCap: 1000});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.startPrank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function testFuzz_WhenDefaultCapIsNotZero(uint256 _defaultCap) external whenCallerIsTheEmissionAdmin {
        // It should set the new default cap for gauges
        // It should emit a {DefaultCapSet} event
        _defaultCap = bound(_defaultCap, 1, type(uint256).max);

        vm.expectEmit(address(rootGaugeFactory));
        emit IRootGaugeFactory.DefaultCapSet({_newDefaultCap: _defaultCap});
        rootGaugeFactory.setDefaultCap({_defaultCap: _defaultCap});

        assertEq(rootGaugeFactory.defaultCap(), _defaultCap);
    }
}
