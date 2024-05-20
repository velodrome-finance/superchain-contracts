// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../BaseFixture.sol";
import {TestERC20WithTransferFee} from "test/mocks/TestERC20WithTransferFee.sol";

contract RouterTest is BaseFixture {
    Pool public _pool;
    Pool public poolFee;
    TestERC20WithTransferFee public erc20Fee;

    uint256 public constant USDC_100K = 1e11;
    uint256 public constant TOKEN_100K = 1e23;

    function setUp() public override {
        super.setUp();

        deal(address(weth), users.alice, 1e25);

        _addLiquidityToPool(users.alice, address(router), address(weth), address(token1), false, TOKEN_1, USDC_1);
        _pool = Pool(poolFactory.getPool(address(token1), address(weth), false));

        erc20Fee = new TestERC20WithTransferFee("Test Token", "FEE", 18);
        erc20Fee.mint(users.alice, TOKEN_100K);

        _seedPoolsWithLiquidity();

        vm.startPrank(users.alice);
    }

    /// @dev Helper function to deposit liquidity into pool
    function _addLiquidityToPool(
        address _owner,
        address _router,
        address _token0,
        address _token1,
        bool _stable,
        uint256 _amount0,
        uint256 _amount1
    ) internal {
        vm.startPrank(_owner);
        IERC20(_token0).approve(address(_router), _amount0);
        IERC20(_token1).approve(address(_router), _amount1);
        router.addLiquidity(_token0, _token1, _stable, _amount0, _amount1, 0, 0, address(_owner), block.timestamp);
        vm.stopPrank();
    }

    function _seedPoolsWithLiquidity() internal {
        vm.startPrank(users.alice);
        vm.deal(users.alice, TOKEN_100K);
        deal(address(token1), users.alice, USDC_100K);
        token1.approve(address(router), USDC_100K);
        router.addLiquidityETH{value: TOKEN_100K}(
            address(token1), false, USDC_100K, USDC_100K, TOKEN_100K, users.alice, block.timestamp
        );

        vm.startPrank(users.bob);
        vm.deal(users.bob, TOKEN_100K);
        deal(address(token1), users.bob, USDC_100K);
        token1.approve(address(router), USDC_100K);
        router.addLiquidityETH{value: TOKEN_100K}(
            address(token1), false, USDC_100K, USDC_100K, TOKEN_100K, users.alice, block.timestamp
        );
        vm.stopPrank();

        // create pool for transfer fee token
        vm.startPrank(users.alice);
        vm.deal(users.alice, TOKEN_100K);
        deal(address(erc20Fee), users.alice, TOKEN_100K);
        erc20Fee.approve(address(router), TOKEN_100K);
        router.addLiquidityETH{value: TOKEN_100K}(
            address(erc20Fee), false, TOKEN_100K, TOKEN_100K, TOKEN_100K, users.alice, block.timestamp
        );
        poolFee = Pool(poolFactory.getPool(address(erc20Fee), address(weth), false));
        vm.stopPrank();
    }

    function test_RevertIf_SortTokensSameRoute() public {
        vm.expectRevert(IRouter.SameAddresses.selector);
        router.sortTokens(address(_pool), address(_pool));
    }

    function test_RevertIf_SortTokensZeroAddress() public {
        vm.expectRevert(IRouter.ZeroAddress.selector);
        router.sortTokens(address(_pool), address(0));
    }

    function test_RevertIf_SendETHToRouter() public {
        vm.deal(users.alice, TOKEN_1);
        vm.expectRevert(IRouter.OnlyWETH.selector);
        payable(address(router)).transfer(TOKEN_1);
    }

    function test_RemoveETHLiquidity() public {
        vm.deal(users.alice, TOKEN_100K);
        deal(address(token1), users.alice, USDC_100K);
        uint256 initialEth = users.alice.balance;
        uint256 initialToken1 = token1.balanceOf(users.alice);
        uint256 poolInitialEth = address(_pool).balance;
        uint256 poolInitialToken1 = token1.balanceOf(address(_pool));

        // add liquidity to pool
        token1.approve(address(router), USDC_100K);
        weth.approve(address(router), TOKEN_100K);
        (,, uint256 liquidity) = router.addLiquidityETH{value: TOKEN_100K}(
            address(token1), false, USDC_100K, USDC_100K, TOKEN_100K, users.alice, block.timestamp
        );

        assertEq(users.alice.balance, initialEth - TOKEN_100K);
        assertEq(token1.balanceOf(users.alice), initialToken1 - USDC_100K);

        (uint256 amountUSDC, uint256 amountETH) =
            router.quoteRemoveLiquidity(address(token1), address(weth), false, liquidity);

        Pool(_pool).approve(address(router), liquidity);
        router.removeLiquidityETH(
            address(token1), false, liquidity, amountUSDC, amountETH, users.alice, block.timestamp
        );

        assertEq(users.alice.balance, initialEth);
        assertEq(token1.balanceOf(users.alice), initialToken1);
        assertEq(address(_pool).balance, poolInitialEth);
        assertEq(token1.balanceOf(address(_pool)), poolInitialToken1);
    }

    function test_RouterPoolGetAmountsOutAndSwapExactTokensForETH() public {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token1), address(weth), false);

        assertEq(router.getAmountsOut(USDC_1, routes)[1], _pool.getAmountOut(USDC_1, address(token1)));

        uint256[] memory expectedOutput = router.getAmountsOut(USDC_1, routes);
        deal(address(token1), users.alice, USDC_1);
        token1.approve(address(router), USDC_1);
        router.swapExactTokensForETH(USDC_1, expectedOutput[1], routes, users.alice, block.timestamp);
    }

    function test_RouterPoolGetAmountsOutAndSwapExactETHForTokens() public {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(weth), address(token1), false);

        assertEq(router.getAmountsOut(TOKEN_1, routes)[1], _pool.getAmountOut(TOKEN_1, address(weth)));

        uint256[] memory expectedOutput = router.getAmountsOut(TOKEN_1, routes);
        vm.deal(users.alice, TOKEN_1);
        router.swapExactETHForTokens{value: TOKEN_1}(expectedOutput[1], routes, users.alice, block.timestamp);
    }

    // TESTS FOR FEE-ON-TRANSFER TOKENS

    function test_RouterRemoveLiquidityETHSupportingFeeOnTransferTokens() public {
        uint256 liquidity = poolFee.balanceOf(users.alice);

        uint256 currentBalance = erc20Fee.balanceOf(address(poolFee));
        uint256 expectedBalanceAfterRemove = currentBalance - (erc20Fee.fee() * 2);
        // subtract 1,000 as even though we're removing all liquidity, MINIMUM_LIQUIDITY amount remains in pool
        expectedBalanceAfterRemove -= 1000;

        poolFee.approve(address(router), type(uint256).max);
        router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(erc20Fee), false, liquidity, 0, 0, users.alice, block.timestamp
        );

        assertEq(erc20Fee.balanceOf(users.alice), expectedBalanceAfterRemove);
    }
}
