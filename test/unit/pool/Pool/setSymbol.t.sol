// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";

contract SetSymbolTest is BaseFixture {
    Pool public pool;

    function setUp() public override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
    }

    function test_InitialState() public view {
        assertEq(pool.symbol(), "sAMMV2-TTA/TTB");
    }

    function test_SetSymbol() public {
        vm.prank(users.owner);
        pool.setSymbol("Some new symbol");

        assertEq(pool.symbol(), "Some new symbol");
    }

    function test_RevertIf_NotPoolAdmin() public {
        vm.prank(address(users.charlie));
        vm.expectRevert(IPoolFactory.NotPoolAdmin.selector);
        pool.setSymbol("Some new symbol");
    }
}
