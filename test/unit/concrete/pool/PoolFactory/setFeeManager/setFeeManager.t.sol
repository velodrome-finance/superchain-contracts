// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

contract SetFeeManagerTest is BaseFixture {
    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with NotFeeManager
        vm.prank(users.charlie);
        vm.expectRevert(IPoolFactory.NotFeeManager.selector);
        poolFactory.setFeeManager(users.owner);
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank(poolFactory.feeManager());
        _;
        vm.stopPrank();
    }

    function test_WhenTheFeeManagerIsAddressZero() external whenCallerIsFeeManager {
        // It should revert with ZeroAddress
        vm.expectRevert(IPoolFactory.ZeroAddress.selector);
        poolFactory.setFeeManager(address(0));
    }

    function test_WhenTheFeeManagerIsNotAddressZero() external whenCallerIsFeeManager {
        // It should set the new fee manager
        // It should emit a {SetFeeManager} event
        assertNotEq(poolFactory.feeManager(), users.alice);
        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.SetFeeManager({feeManager: users.alice});
        poolFactory.setFeeManager(users.alice);
        assertEq(poolFactory.feeManager(), users.alice);
    }
}
