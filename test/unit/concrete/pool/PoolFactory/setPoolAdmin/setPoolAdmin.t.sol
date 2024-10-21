// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../PoolFactory.t.sol";

contract SetPoolAdminTest is PoolFactoryTest {
    function test_WhenCallerIsNotPoolAdmin() external {
        // It should revert with NotPoolAdmin
        vm.expectRevert(IPoolFactory.NotPoolAdmin.selector);
        vm.startPrank(users.charlie);
        poolFactory.setPoolAdmin(users.charlie);
    }

    modifier whenCallerIsPoolAdmin() {
        vm.startPrank(users.owner);
        _;
        vm.stopPrank();
    }

    function test_WhenThePoolAdminIsAddressZero() external whenCallerIsPoolAdmin {
        // It should revert with ZeroAddress
        vm.expectRevert(IPoolFactory.ZeroAddress.selector);
        poolFactory.setPoolAdmin(address(0));
    }

    function test_WhenThePoolAdminIsNotAddressZero() external whenCallerIsPoolAdmin {
        // It should set the new pool admin
        // It should emit a {SetPoolAdmin} event
        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.SetPoolAdmin({poolAdmin: users.alice});
        poolFactory.setPoolAdmin(users.alice);

        assertEq(poolFactory.poolAdmin(), users.alice);
    }
}
