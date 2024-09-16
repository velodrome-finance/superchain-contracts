// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../EmergencyCouncilE2E.t.sol";

contract SetPoolSymbolE2ETest is EmergencyCouncilE2ETest {
    address pool = 0xbC26519f936A90E78fe2C9aA2A03CC208f041234;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        emergencyCouncil.setPoolSymbol(pool, "SYMBOL");
    }

    function test_WhenCallerIsOwner() external {
        // It should set the pool symbol
        string memory symbol = Pool(pool).symbol();
        assertNotEq(symbol, "SYMBOL");
        vm.startPrank(users.owner);
        emergencyCouncil.setPoolSymbol(pool, "SYMBOL");
        assertEq(Pool(pool).symbol(), "SYMBOL");
    }
}
