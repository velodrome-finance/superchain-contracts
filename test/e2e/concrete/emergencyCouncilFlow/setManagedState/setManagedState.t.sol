// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../EmergencyCouncilE2E.t.sol";

contract SetManagedStateE2ETest is EmergencyCouncilE2ETest {
    uint256 mTokenId = 20264;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        emergencyCouncil.setManagedState(mTokenId, true);
    }

    function test_WhenCallerIsOwner() external {
        // It should set the managed state
        assertFalse(mockEscrow.deactivated(mTokenId));
        vm.startPrank(users.owner);
        emergencyCouncil.setManagedState(mTokenId, true);
        assertTrue(mockEscrow.deactivated(mTokenId));
    }
}
