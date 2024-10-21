// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../PoolFactory.t.sol";

contract SetPauserTest is PoolFactoryTest {
    function test_WhenCallerIsNotPauser() external {
        // It should revert with NotPauser
        vm.prank(users.charlie);
        vm.expectRevert(IPoolFactory.NotPauser.selector);
        poolFactory.setPauser(users.alice);
    }

    modifier whenCallerIsPauser() {
        vm.startPrank(poolFactory.pauser());
        _;
        vm.stopPrank();
    }

    function test_WhenThePauserIsAddressZero() external whenCallerIsPauser {
        // It should revert with ZeroAddress
        vm.expectRevert(IPoolFactory.ZeroAddress.selector);
        poolFactory.setPauser(address(0));
    }

    function test_WhenThePauserIsNotAddressZero() external whenCallerIsPauser {
        // It should set the new pauser
        // It should emit a {SetPauser} event
        assertNotEq(poolFactory.pauser(), users.alice);

        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.SetPauser({pauser: users.alice});
        poolFactory.setPauser(users.alice);
        assertEq(poolFactory.pauser(), users.alice);
    }
}
