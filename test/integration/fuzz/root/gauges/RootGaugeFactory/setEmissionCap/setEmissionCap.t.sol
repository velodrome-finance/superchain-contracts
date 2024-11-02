// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract SetEmissionCapIntegrationFuzzTest is RootGaugeFactoryTest {
    function testFuzz_WhenCallerIsNotTheEmissionAdmin(address _caller) external {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != rootGaugeFactory.emissionAdmin());

        vm.prank(_caller);
        vm.expectRevert(IRootGaugeFactory.NotAuthorized.selector);
        rootGaugeFactory.setEmissionCap({_gauge: address(0), _emissionCap: 1000});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.startPrank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function test_WhenEmissionCapIsGreaterThanMaxBps(address _gauge, uint256 _emissionCap)
        external
        whenCallerIsTheEmissionAdmin
    {
        // It should revert with {MaximumCapExceeded}
        vm.assume(_gauge != address(0));
        _emissionCap = bound(_emissionCap, 10_001, type(uint256).max);
        vm.expectRevert(IRootGaugeFactory.MaximumCapExceeded.selector);
        rootGaugeFactory.setEmissionCap({_gauge: _gauge, _emissionCap: _emissionCap});
    }

    function testFuzz_WhenEmissionCapIsLessOrEqualToMaxBps(address _gauge, uint256 _emissionCap)
        external
        whenCallerIsTheEmissionAdmin
    {
        // It should set the new emission cap for the gauge
        // It should emit a {EmissionCapSet} event
        vm.assume(_gauge != address(0));
        _emissionCap = bound(_emissionCap, 0, 10_000);

        vm.expectEmit(address(rootGaugeFactory));
        emit IRootGaugeFactory.EmissionCapSet({_gauge: _gauge, _newEmissionCap: _emissionCap});
        rootGaugeFactory.setEmissionCap({_gauge: _gauge, _emissionCap: _emissionCap});

        // @dev If `emissionCap` is set to 0, `defaultCap` should be returned
        _emissionCap = _emissionCap == 0 ? rootGaugeFactory.defaultCap() : _emissionCap;
        assertEq(rootGaugeFactory.emissionCaps(_gauge), _emissionCap);
    }
}
