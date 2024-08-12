// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract SetEmergencyCouncilIntegrationConcreteTest is LeafVoterTest {
    function test_WhenCallerIsNotEmergencyCouncil() external {
        // It should revert with NotEmergencyCouncil
        vm.expectRevert(ILeafVoter.NotEmergencyCouncil.selector);
        vm.prank(users.charlie);
        leafVoter.setEmergencyCouncil(users.charlie);
    }

    modifier whenCallerIsEmergencyCouncil() {
        vm.startPrank(leafVoter.emergencyCouncil());
        _;
    }

    function test_WhenNewCouncilIsZeroAddress() external whenCallerIsEmergencyCouncil {
        // It should revert with ZeroAddress
        vm.expectRevert(ILeafVoter.ZeroAddress.selector);
        leafVoter.setEmergencyCouncil(address(0));
    }

    function test_WhenNewCouncilIsNotZeroAddress() external whenCallerIsEmergencyCouncil {
        // It should set new emergency council
        // It should emit a {SetEmergencyCouncil} event
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.SetEmergencyCouncil({emergencyCouncil: users.deployer});
        leafVoter.setEmergencyCouncil(users.deployer);

        assertEq(leafVoter.emergencyCouncil(), users.deployer);
    }
}
