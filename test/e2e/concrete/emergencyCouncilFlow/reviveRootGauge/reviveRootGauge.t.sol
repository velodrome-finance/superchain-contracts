// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../EmergencyCouncilE2E.t.sol";

contract ReviveRootGaugeE2ETest is EmergencyCouncilE2ETest {
    using stdStorage for StdStorage;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        emergencyCouncil.reviveRootGauge(address(rootGauge));
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenGaugeIsAlive() external whenCallerIsOwner {
        // It should revert with GaugeAlreadyRevived
        vm.expectRevert(IVoter.GaugeAlreadyRevived.selector);
        emergencyCouncil.reviveRootGauge(address(rootGauge));
    }

    function test_WhenGaugeIsNotAlive() external whenCallerIsOwner {
        // It should set isAlive as true for gauge
        // It should emit a {GaugeRevived} event
        stdstore.target(address(mockVoter)).sig("isAlive(address)").with_key(address(rootGauge)).checked_write(false);
        vm.expectEmit(address(mockVoter));
        emit IVoter.GaugeRevived({gauge: address(rootGauge)});
        emergencyCouncil.reviveRootGauge(address(rootGauge));

        assertEq(mockVoter.isAlive(address(rootGauge)), true);
    }
}
