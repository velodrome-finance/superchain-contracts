// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../EmergencyCouncilE2E.t.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";

contract SetPoolNameE2ETest is EmergencyCouncilE2ETest {
    address pool = 0xbC26519f936A90E78fe2C9aA2A03CC208f041234;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        emergencyCouncil.setPoolName(pool, "New Name");
    }

    function test_WhenCallerIsOwner() external {
        // It should set the pool name
        string memory name = Pool(pool).name();
        assertNotEq(name, "New Name");
        vm.startPrank(users.owner);
        emergencyCouncil.setPoolName(pool, "New Name");
        assertEq(Pool(pool).name(), "New Name");
    }
}
