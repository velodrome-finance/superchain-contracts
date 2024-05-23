// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";

contract PoolFeesTest is BaseFixture {
    Pool public pool;

    function setUp() public override {
        super.setUp();
        pool = Pool(poolFactory.createPool(address(token0), address(token1), true));

        addLiquidityToPool(users.alice, address(token0), address(token1), true, TOKEN0_1, TOKEN1_1);

        vm.prank(users.feeManager);
        poolFactory.setFee(true, 2); // 2 bps = 0.02%
    }

    function test_SwapAndClaimFees() public {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(token1), true);

        assertEq(router.getAmountsOut(TOKEN0_1, routes)[1], pool.getAmountOut(TOKEN0_1, address(token0)));

        uint256[] memory assertedOutput = router.getAmountsOut(TOKEN0_1, routes);

        vm.startPrank(users.bob);
        token0.approve(address(router), TOKEN0_1);
        router.swapExactTokensForTokens(TOKEN0_1, assertedOutput[1], routes, address(users.bob), block.timestamp);
        vm.stopPrank();

        skip(1801);
        vm.roll(block.number + 1);
        address poolFees = pool.poolFees();
        assertEq(token0.balanceOf(poolFees), TOKEN0_1 / 10000 * 2); // 0.02% of TOKEN0_1
        uint256 b = token0.balanceOf(address(users.alice));

        vm.prank(users.alice);
        pool.claimFees();
        assertGt(token0.balanceOf(address(users.alice)), b);
    }

    function test_FeeManagerCanChangeFeesAndClaim() public {
        vm.prank(users.feeManager);
        poolFactory.setFee(true, 3); // 3 bps = 0.03%

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(token1), true);

        assertEq(router.getAmountsOut(TOKEN0_1, routes)[1], pool.getAmountOut(TOKEN0_1, address(token0)));

        uint256[] memory assertedOutput = router.getAmountsOut(TOKEN0_1, routes);

        vm.startPrank(users.bob);
        token0.approve(address(router), TOKEN0_1);
        router.swapExactTokensForTokens(TOKEN0_1, assertedOutput[1], routes, address(users.bob), block.timestamp);
        vm.stopPrank();

        skip(1801);
        vm.roll(block.number + 1);
        address poolFees = pool.poolFees();
        assertEq(token0.balanceOf(poolFees), TOKEN0_1 / 10000 * 3); // 0.03% of TOKEN0_1
        uint256 b = token0.balanceOf(address(users.alice));

        vm.prank(users.alice);
        pool.claimFees();

        assertGt(token0.balanceOf(address(users.alice)), b);
    }
}
