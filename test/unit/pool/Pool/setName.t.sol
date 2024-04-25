// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";

contract SetNameTest is BaseFixture {
    Pool public pool;

    function setUp() public override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
    }

    function test_InitialState() public view {
        assertEq(pool.name(), "StableV2 AMM - TTA/TTB");
    }

    function test_SetName() public {
        vm.prank(users.owner);
        pool.setName("Some new name");
        assertEq(pool.name(), "Some new name");
    }

    function test_RevertIf_NotPoolAdmin() public {
        vm.expectRevert(IPoolFactory.NotPoolAdmin.selector);
        vm.prank(address(users.charlie));
        pool.setName("Some new name");
    }
}
