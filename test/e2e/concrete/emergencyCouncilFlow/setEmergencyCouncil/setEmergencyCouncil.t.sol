// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../EmergencyCouncilE2E.t.sol";

contract SetEmergencyCouncilE2ETest is EmergencyCouncilE2ETest {
    function test_WhenCallerIsNotOwner() external {
        // It should revert with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        emergencyCouncil.setEmergencyCouncil({_council: users.charlie});
    }

    function test_WhenCallerIsOwner() external {
        // It should set the new emergency council
        assertEq(mockVoter.emergencyCouncil(), address(emergencyCouncil));
        vm.startPrank(users.owner);
        emergencyCouncil.setEmergencyCouncil({_council: users.alice});
        assertEq(mockVoter.emergencyCouncil(), users.alice);
    }
}
