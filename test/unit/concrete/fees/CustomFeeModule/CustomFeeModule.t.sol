// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

abstract contract CustomFeeModuleTest is BaseFixture {
    function setUp() public virtual override {
        super.setUp();

        vm.prank(poolFactory.feeManager());
        poolFactory.setFeeModule({_feeModule: address(feeModule)});
    }

    function test_InitialState() public view {
        assertEq(address(feeModule.factory()), address(poolFactory));
    }
}
