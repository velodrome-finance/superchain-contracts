// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

contract PoolFeesTest is BaseFixture {
    Pool public pool;
    uint256 public token0Amount;
    uint256 public token1Amount;

    function setUp() public override {
        super.setUp();
        pool = Pool(poolFactory.createPool(address(token0), address(token1), true));

        // amounts normalized by decimals
        token0Amount = 10 ** (token0.decimals() - 1);
        token1Amount = 10 ** (token1.decimals() - 1);

        addLiquidityToPool(users.alice, address(token0), address(token1), true, token0Amount, token1Amount);

        vm.prank(users.feeManager);
        poolFactory.setFee(true, 2); // 2 bps = 0.02%
    }

    function test_SwapAndClaimFees() public {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(token1), true);

        assertEq(router.getAmountsOut(token0Amount, routes)[1], pool.getAmountOut(token0Amount, address(token0)));

        uint256[] memory assertedOutput = router.getAmountsOut(token0Amount, routes);

        vm.startPrank(users.bob);
        token0.approve(address(router), token0Amount);
        router.swapExactTokensForTokens(token0Amount, assertedOutput[1], routes, address(users.bob), block.timestamp);
        vm.stopPrank();

        skip(1801);
        vm.roll(block.number + 1);
        address poolFees = pool.poolFees();
        assertEq(token0.balanceOf(poolFees), token0Amount * 2 / 10_000); // 0.02% of token0Amount
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

        assertEq(router.getAmountsOut(token0Amount, routes)[1], pool.getAmountOut(token0Amount, address(token0)));

        uint256[] memory assertedOutput = router.getAmountsOut(token0Amount, routes);

        vm.startPrank(users.bob);
        token0.approve(address(router), token0Amount);
        router.swapExactTokensForTokens(token0Amount, assertedOutput[1], routes, address(users.bob), block.timestamp);
        vm.stopPrank();

        skip(1801);
        vm.roll(block.number + 1);
        address poolFees = pool.poolFees();
        assertEq(token0.balanceOf(poolFees), token0Amount * 3 / 10_000); // 0.03% of token0Amount
        uint256 b = token0.balanceOf(address(users.alice));

        vm.prank(users.alice);
        pool.claimFees();

        assertGt(token0.balanceOf(address(users.alice)), b);
    }
}
