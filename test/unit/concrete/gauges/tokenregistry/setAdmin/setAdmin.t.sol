// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import "../TokenRegistry.t.sol";

contract SetAdminTest is TokenRegistryTest {
    function test_WhenCallerIsNotAdmin() external {
        // It should revert with NotAdmin
        vm.prank(users.alice);
        vm.expectRevert(ITokenRegistry.NotAdmin.selector);
        tokenRegistry.setAdmin({_admin: users.bob});
    }

    modifier whenCallerIsAdmin() {
        vm.startPrank(tokenRegistry.admin());
        _;
    }

    function test_WhenTheGivenAdminIsTheZeroAddress() external whenCallerIsAdmin {
        // It should revert with ZeroAddress
        vm.expectRevert(ITokenRegistry.ZeroAddress.selector);
        tokenRegistry.setAdmin({_admin: address(0)});
    }

    function test_WhenTheGivenAdminIsNotTheZeroAddress() external whenCallerIsAdmin {
        // It should set the new Admin
        // It should emit {SetAdmin} event
        vm.expectEmit(true, true, true, true, address(tokenRegistry));
        emit ITokenRegistry.SetAdmin({admin: users.bob});
        tokenRegistry.setAdmin({_admin: users.bob});
    }
}
