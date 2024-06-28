// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

contract SetPauseStateTest is BaseFixture {
    function test_WhenCallerIsNotPauser() external {
        // It should revert with NotPauser
        vm.prank(users.charlie);
        vm.expectRevert(IPoolFactory.NotPauser.selector);
        poolFactory.setPauseState(true);
    }

    modifier whenCallerIsPauser() {
        vm.startPrank(poolFactory.pauser());
        _;
        vm.stopPrank();
    }

    function test_WhenTheStateIsTrue() external whenCallerIsPauser {
        // It should set the pool factory paused state to true
        // It should emit a {SetPauseState} event
        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.SetPauseState({state: true});
        poolFactory.setPauseState(true);
        assertEq(poolFactory.isPaused(), true);
    }

    function test_WhenTheStateIsFalse() external whenCallerIsPauser {
        //set the pool factory paused state to true
        poolFactory.setPauseState(true);
        assertTrue(poolFactory.isPaused());

        // It should set the pool factory paused state to false
        // It should emit a {SetPauseState} event
        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.SetPauseState({state: false});
        poolFactory.setPauseState(false);
        assertEq(poolFactory.isPaused(), false);
    }
}
