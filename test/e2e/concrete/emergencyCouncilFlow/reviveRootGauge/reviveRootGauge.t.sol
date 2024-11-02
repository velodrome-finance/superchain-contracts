// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../EmergencyCouncilE2E.t.sol";

contract ReviveRootGaugeE2ETest is EmergencyCouncilE2ETest {
    using stdStorage for StdStorage;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        emergencyCouncil.reviveRootGauge(gauge);
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenGaugeIsNotAGauge() external whenCallerIsOwner {
        // It should revert with InvalidGauge
        vm.expectRevert(IEmergencyCouncil.InvalidGauge.selector);
        emergencyCouncil.reviveLeafGauge(gauge);
    }

    modifier whenGaugeIsAGauge() {
        gauge = address(rootGauge);
        _;
    }

    function test_WhenGaugeIsLeafGauge() external whenCallerIsOwner whenGaugeIsAGauge {
        // It should revert with InvalidGauge
        vm.expectRevert(abi.encodeWithSelector(IEmergencyCouncil.InvalidGauge.selector));
        emergencyCouncil.reviveRootGauge(gauge);
    }

    modifier whenGaugeIsNotLeafGauge() {
        /// @dev Simulate revert to mimic non superchain gauge
        vm.mockCallRevert({callee: gauge, data: abi.encodeWithSelector(IRootGauge.chainid.selector), revertData: ""});
        _;
    }

    function test_WhenGaugeIsAlive() external whenCallerIsOwner whenGaugeIsAGauge whenGaugeIsNotLeafGauge {
        // It should revert with GaugeAlreadyRevived
        vm.expectRevert(IVoter.GaugeAlreadyRevived.selector);
        emergencyCouncil.reviveRootGauge(gauge);
    }

    function test_WhenGaugeIsNotAlive() external whenCallerIsOwner whenGaugeIsAGauge whenGaugeIsNotLeafGauge {
        // It should set isAlive as true for gauge
        // It should emit a {GaugeRevived} event
        stdstore.target(address(mockVoter)).sig("isAlive(address)").with_key(gauge).checked_write(false);
        vm.expectEmit(address(mockVoter));
        emit IVoter.GaugeRevived({gauge: gauge});
        emergencyCouncil.reviveRootGauge(gauge);

        assertEq(mockVoter.isAlive(gauge), true);
    }
}
