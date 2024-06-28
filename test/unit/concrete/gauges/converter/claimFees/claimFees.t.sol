// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import "../Converter.t.sol";

contract ClaimFeesTest is ConverterTest {
    function test_WhenCallerIsNotAKeeper() external {
        // It should revert with NotKeeper()
        vm.expectRevert(IConverter.NotKeeper.selector);
        feeConverter.claimFees();
    }

    modifier whenCallerIsAKeeper() {
        _;
    }

    function test_GivenThatThereIsNoLiquidityStaked() external whenCallerIsAKeeper {
        // no deposit of liquidity into `stakingRewards` contract
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(token1), true);

        assertEq(router.getAmountsOut(TOKEN_1, routes)[1], pool.getAmountOut(TOKEN_1, address(token0)));
        uint256 poolFee = poolFactory.getFee(address(pool), pool.stable());
        assertEq(poolFee, 5); // 0.05% fee

        // execute swap to accrue fees
        uint256[] memory assertedOutput = router.getAmountsOut(TOKEN_1, routes);
        token0.approve(address(router), TOKEN_1);
        router.swapExactTokensForTokens(TOKEN_1, assertedOutput[1], routes, address(users.alice), block.timestamp);

        skip(1801);
        vm.roll(block.number + 1);

        address poolFees = pool.poolFees();
        uint256 expectedSwapFee = TOKEN_1 * poolFee / 10_000;
        // ensure fees accrued correctly
        assertEq(token0.balanceOf(poolFees), expectedSwapFee);

        // It should not receive any Fees
        vm.startPrank(stakingRewardsFactory.keepers()[0]);
        feeConverter.claimFees();
        assertEq(token0.balanceOf(address(feeConverter)), 0);

        // alice can claim all available fees with unstaked liquidity
        uint256 balBefore = token0.balanceOf(address(users.alice));
        vm.startPrank(users.alice);
        pool.claimFees();
        assertApproxEqAbs(token0.balanceOf(address(users.alice)), balBefore + expectedSwapFee, 1e2);
    }

    modifier givenThatThereIsLiquidityStaked() {
        _;
    }

    function test_GivenThatAllLiquidityIsStaked() external whenCallerIsAKeeper givenThatThereIsLiquidityStaked {
        // deposit all liquidity into `stakingRewards` contract
        uint256 depositAmount = pool.balanceOf(users.alice);
        pool.approve(address(stakingRewards), depositAmount);
        stakingRewards.deposit(depositAmount, users.alice);

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(token1), true);

        assertEq(router.getAmountsOut(TOKEN_1, routes)[1], pool.getAmountOut(TOKEN_1, address(token0)));
        uint256 poolFee = poolFactory.getFee(address(pool), pool.stable());
        assertEq(poolFee, 5); // 0.05% fee

        // execute swap to accrue fees
        uint256[] memory assertedOutput = router.getAmountsOut(TOKEN_1, routes);
        token0.approve(address(router), TOKEN_1);
        router.swapExactTokensForTokens(TOKEN_1, assertedOutput[1], routes, address(users.alice), block.timestamp);

        skip(1801);
        vm.roll(block.number + 1);

        address poolFees = pool.poolFees();
        uint256 expectedSwapFee = TOKEN_1 * poolFee / 10_000;
        // check fees accrued correctly
        assertEq(token0.balanceOf(poolFees), expectedSwapFee);

        vm.startPrank(stakingRewardsFactory.keepers()[0]);
        // It should emit a {Claimed} event inside the StakingRewards contract
        vm.expectEmit(true, true, true, false, address(stakingRewards));
        emit IStakingRewards.ClaimFees({claimed0: expectedSwapFee, claimed1: 0});
        feeConverter.claimFees();
        // It should receive all accumulated Pool fees
        assertApproxEqAbs(token0.balanceOf(address(feeConverter)), expectedSwapFee, 1e2);
    }

    function test_GivenThatAPortionOfLiquidityIsStaked() external whenCallerIsAKeeper givenThatThereIsLiquidityStaked {
        // deposit half of liquidity into `stakingRewards` contract
        uint256 depositAmount = pool.balanceOf(users.alice) / 2;
        pool.approve(address(stakingRewards), depositAmount);
        stakingRewards.deposit(depositAmount, users.alice);

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(token1), true);

        assertEq(router.getAmountsOut(TOKEN_1, routes)[1], pool.getAmountOut(TOKEN_1, address(token0)));
        uint256 poolFee = poolFactory.getFee(address(pool), pool.stable());
        assertEq(poolFee, 5); // 0.05% fee

        // execute swap to accrue fees
        uint256[] memory assertedOutput = router.getAmountsOut(TOKEN_1, routes);
        token0.approve(address(router), TOKEN_1);
        router.swapExactTokensForTokens(TOKEN_1, assertedOutput[1], routes, address(users.alice), block.timestamp);

        skip(1801);
        vm.roll(block.number + 1);

        address poolFees = pool.poolFees();
        uint256 expectedSwapFee = TOKEN_1 * poolFee / 10_000;
        // check fees accrued correctly
        assertEq(token0.balanceOf(poolFees), expectedSwapFee);

        // alice can claim half of all fees, since only half of liquidity is unstaked
        uint256 balBefore = token0.balanceOf(address(users.alice));
        pool.claimFees();
        assertApproxEqAbs(token0.balanceOf(address(users.alice)), balBefore + expectedSwapFee / 2, 1e2);

        // It should emit a {Claimed} event inside the StakingRewards contract
        vm.startPrank(stakingRewardsFactory.keepers()[0]);
        vm.expectEmit(true, true, true, false, address(stakingRewards));
        emit IStakingRewards.ClaimFees({claimed0: expectedSwapFee / 2, claimed1: 0});
        feeConverter.claimFees();
        // It should receive an amount of Pool Fees proportional to the amount of Liquidity that is staked in StakingRewards
        assertApproxEqAbs(token0.balanceOf(address(feeConverter)), expectedSwapFee / 2, 1e2);
    }
}
