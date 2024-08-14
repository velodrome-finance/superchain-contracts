// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract SetEmergencyCouncilIntegrationFuzzTest is LeafVoterTest {
    function testFuzz_WhenCallerIsNotEmergencyCouncil(address _caller) external {
        vm.assume(_caller != leafVoter.emergencyCouncil());
        // It should revert with NotEmergencyCouncil
        vm.expectRevert(ILeafVoter.NotEmergencyCouncil.selector);
        vm.prank(_caller);
        leafVoter.setEmergencyCouncil(_caller);
    }

    modifier whenCallerIsEmergencyCouncil() {
        vm.startPrank(leafVoter.emergencyCouncil());
        _;
    }

    function testFuzz_WhenNewCouncilIsNotZeroAddress(address _council) external whenCallerIsEmergencyCouncil {
        vm.assume(_council != address(0));
        // It should set new emergency council
        // It should emit a {SetEmergencyCouncil} event
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.SetEmergencyCouncil({emergencyCouncil: _council});
        leafVoter.setEmergencyCouncil(_council);

        assertEq(leafVoter.emergencyCouncil(), _council);
    }
}
