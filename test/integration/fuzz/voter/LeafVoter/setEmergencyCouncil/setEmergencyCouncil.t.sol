// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract SetEmergencyCouncilIntegrationFuzzTest is LeafVoterTest {
    function testFuzz_WhenCallerIsNotEmergencyCouncil(address caller) external {
        vm.assume(caller != leafVoter.emergencyCouncil());
        // It should revert with NotEmergencyCouncil
        vm.expectRevert(ILeafVoter.NotEmergencyCouncil.selector);
        vm.prank(caller);
        leafVoter.setEmergencyCouncil(caller);
    }

    modifier whenCallerIsEmergencyCouncil() {
        vm.startPrank(leafVoter.emergencyCouncil());
        _;
    }

    function testFuzz_WhenNewCouncilIsNotZeroAddress(address council) external whenCallerIsEmergencyCouncil {
        vm.assume(council != address(0));
        // It should set new emergency council
        // It should emit a {SetEmergencyCouncil} event
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.SetEmergencyCouncil({emergencyCouncil: council});
        leafVoter.setEmergencyCouncil(council);

        assertEq(leafVoter.emergencyCouncil(), council);
    }
}
