// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";

contract SetPoolAdminTest is BaseFixture {
    function setUp() public override {
        super.setUp();

        vm.startPrank(users.owner);
    }

    function test_InitialState() public view {
        assertEq(poolFactory.poolAdmin(), users.owner);
    }

    function test_SetPoolAdmin() public {
        vm.expectEmit(true, true, true, true);
        emit IPoolFactory.SetPoolAdmin({poolAdmin: users.alice});
        poolFactory.setPoolAdmin(users.alice);

        assertEq(poolFactory.poolAdmin(), users.alice);
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert(IPoolFactory.ZeroAddress.selector);
        poolFactory.setPoolAdmin(address(0));
    }

    function test_RevertIf_NotPoolAdmin() public {
        vm.stopPrank();

        vm.expectRevert(IPoolFactory.NotPoolAdmin.selector);
        vm.startPrank(users.charlie);
        poolFactory.setPoolAdmin(users.charlie);
    }
}
