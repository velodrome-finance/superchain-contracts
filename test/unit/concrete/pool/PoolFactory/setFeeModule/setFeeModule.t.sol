// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../PoolFactory.t.sol";

contract SetFeeModuleTest is PoolFactoryTest {
    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with {NotFeeManager}
        vm.prank(users.charlie);
        vm.expectRevert(IPoolFactory.NotFeeManager.selector);
        poolFactory.setFeeModule(users.owner);
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank(poolFactory.feeManager());
        _;
        vm.stopPrank();
    }

    function test_WhenTheFeeModuleIsAddressZero() external whenCallerIsFeeManager {
        // It should revert with {ZeroAddress}
        vm.expectRevert(IPoolFactory.ZeroAddress.selector);
        poolFactory.setFeeModule(address(0));
    }

    function test_WhenTheFeeModuleIsNotAddressZero() external whenCallerIsFeeManager {
        // It should set the new fee module
        // It should emit a {FeeModuleChanged} event
        assertNotEq(poolFactory.feeModule(), address(feeModule));
        vm.expectEmit(address(poolFactory));
        emit IPoolFactory.FeeModuleChanged({oldFeeModule: address(0), newFeeModule: address(feeModule)});
        poolFactory.setFeeModule(address(feeModule));
        assertEq(poolFactory.feeModule(), address(feeModule));
    }
}
