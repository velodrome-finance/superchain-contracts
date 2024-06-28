// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../Converter.t.sol";

contract SwapTokenToTokenTest is ConverterTest {
    uint256 public constant MINIMUM_OBSERVATIONS = 3;

    function setUp() public override {
        super.setUp();
        deal(address(rewardToken), users.alice, TOKEN_1 * 1e10);

        address _pool = _createPoolAndSimulateSwaps({
            tokenA: address(token0),
            tokenB: address(rewardToken),
            stable: true,
            amountA: TOKEN_1,
            amountB: TOKEN_1
        });
        vm.label(_pool, "Pool Token0");
        _pool = _createPoolAndSimulateSwaps({
            tokenA: address(token1),
            tokenB: address(rewardToken),
            stable: true,
            amountA: TOKEN_1,
            amountB: USDC_1
        });
        vm.label(_pool, "Pool Token1");
    }

    /// @dev Helper to create a Pool and simulate multiple Swaps to write Observations
    function _createPoolAndSimulateSwaps(address tokenA, address tokenB, bool stable, uint256 amountA, uint256 amountB)
        internal
        returns (address _pool)
    {
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        _pool = poolFactory.createPool({tokenA: address(tokenA), tokenB: address(tokenB), stable: stable});

        addLiquidityToPool({
            _owner: users.alice,
            _token0: tokenA,
            _token1: tokenB,
            _stable: stable,
            _amount0: amountA * 10_000,
            _amount1: amountB * 10_000
        });

        /// @dev Simulate swaps to write a minimum of 3 observations, to enable quote fetching
        vm.startPrank(users.bob);
        for (uint256 i = 0; i < MINIMUM_OBSERVATIONS; i++) {
            if (i % 2 == 0) {
                _simulateSwap({tokenIn: address(tokenA), tokenOut: address(tokenB), stable: stable, amount: amountA});
            } else {
                _simulateSwap({tokenIn: address(tokenB), tokenOut: address(tokenA), stable: stable, amount: amountB});
            }
        }
        vm.stopPrank();
    }

    /// @dev Helper to Simulate a single Swap and write an Observation
    function _simulateSwap(address tokenIn, address tokenOut, bool stable, uint256 amount) internal {
        skip(1801); // Skipping 30 minutes so new Observation is written
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(tokenIn, tokenOut, stable);

        address _pool = poolFactory.getPool(tokenIn, tokenOut, stable);

        assertEq(router.getAmountsOut(amount, routes)[1], IPool(_pool).getAmountOut(amount, tokenIn));

        uint256[] memory assertedOutput = router.getAmountsOut(amount, routes);
        deal(tokenIn, users.bob, amount);
        IERC20(tokenIn).approve(address(router), amount);
        router.swapExactTokensForTokens({
            amountIn: amount,
            amountOutMin: assertedOutput[1],
            routes: routes,
            to: address(users.alice),
            deadline: block.timestamp
        });
    }

    function test_WhenCallerIsNotKeeper() external {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(rewardToken), true);
        assertFalse(stakingRewardsFactory.isKeeper(users.charlie));

        // It should revert with NotKeeper
        vm.startPrank(users.charlie);
        vm.expectRevert(IConverter.NotKeeper.selector);
        feeConverter.swapTokenToToken({_token: address(token0), _slippage: 500, _routes: routes});
    }

    modifier whenCallerIsKeeper() {
        vm.startPrank(stakingRewardsFactory.keepers()[0]);
        _;
    }

    function test_WhenSlippageExceedsMAX_SLIPPAGE() external whenCallerIsKeeper {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(rewardToken), true);

        uint256 slippage = feeConverter.MAX_SLIPPAGE() + 1;

        // It should revert with SlippageTooHigh
        vm.expectRevert(IConverter.SlippageTooHigh.selector);
        feeConverter.swapTokenToToken({_token: address(token0), _slippage: slippage, _routes: routes});
    }

    modifier whenSlippageDoesNotExceedMAX_SLIPPAGE() {
        _;
    }

    function test_WhenTokenToSwapIsTheZeroAddress() external whenCallerIsKeeper whenSlippageDoesNotExceedMAX_SLIPPAGE {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(rewardToken), true);

        // It should revert with ZeroAddress
        vm.expectRevert(IConverter.ZeroAddress.selector);
        feeConverter.swapTokenToToken({_token: address(0), _slippage: 500, _routes: routes});
    }

    modifier whenTokenToSwapIsNotTheZeroAddress() {
        _;
    }

    function test_WhenTokenToSwapIsTargetToken()
        external
        whenCallerIsKeeper
        whenSlippageDoesNotExceedMAX_SLIPPAGE
        whenTokenToSwapIsNotTheZeroAddress
    {
        IRouter.Route[] memory routes = new IRouter.Route[](0);

        // It should revert with InvalidPath
        vm.expectRevert(IConverter.InvalidPath.selector);
        feeConverter.swapTokenToToken({_token: address(rewardToken), _slippage: 500, _routes: routes});
    }

    modifier whenTokenToSwapIsNotTargetToken() {
        _;
    }

    function test_WhenNoRoutesAreGiven()
        external
        whenCallerIsKeeper
        whenSlippageDoesNotExceedMAX_SLIPPAGE
        whenTokenToSwapIsNotTheZeroAddress
        whenTokenToSwapIsNotTargetToken
    {
        IRouter.Route[] memory routes = new IRouter.Route[](0);

        // It should revert with InvalidPath
        vm.expectRevert(IConverter.InvalidPath.selector);
        feeConverter.swapTokenToToken({_token: address(token0), _slippage: 500, _routes: routes});
    }

    modifier whenRoutesAreGiven() {
        _;
    }

    function test_WhenInputTokenOfFirstRouteIsNotTokenToSwap()
        external
        whenCallerIsKeeper
        whenSlippageDoesNotExceedMAX_SLIPPAGE
        whenTokenToSwapIsNotTheZeroAddress
        whenTokenToSwapIsNotTargetToken
        whenRoutesAreGiven
    {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(rewardToken), true);

        // It should revert with InvalidPath
        vm.expectRevert(IConverter.InvalidPath.selector);
        feeConverter.swapTokenToToken({_token: address(token1), _slippage: 500, _routes: routes});
    }

    modifier whenInputTokenOfFirstRouteIsTokenToSwap() {
        _;
    }

    function test_WhenOutputTokenOfLastRouteIsNotTargetToken()
        external
        whenCallerIsKeeper
        whenSlippageDoesNotExceedMAX_SLIPPAGE
        whenTokenToSwapIsNotTheZeroAddress
        whenTokenToSwapIsNotTargetToken
        whenRoutesAreGiven
        whenInputTokenOfFirstRouteIsTokenToSwap
    {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(token1), true);

        // It should revert with InvalidPath
        vm.expectRevert(IConverter.InvalidPath.selector);
        feeConverter.swapTokenToToken({_token: address(token0), _slippage: 500, _routes: routes});
    }

    modifier whenOutputTokenOfLastRouteIsTargetToken() {
        _;
    }

    function test_GivenBalanceInTokenToSwapIsZero()
        external
        whenCallerIsKeeper
        whenSlippageDoesNotExceedMAX_SLIPPAGE
        whenTokenToSwapIsNotTheZeroAddress
        whenTokenToSwapIsNotTargetToken
        whenRoutesAreGiven
        whenInputTokenOfFirstRouteIsTokenToSwap
        whenOutputTokenOfLastRouteIsTargetToken
    {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(rewardToken), true);

        // It should revert with AmountInZero
        vm.expectRevert(IConverter.AmountInZero.selector);
        feeConverter.swapTokenToToken({_token: address(token0), _slippage: 500, _routes: routes});
    }

    modifier givenBalanceInTokenToSwapIsNotZero() {
        deal(address(token0), address(feeConverter), TOKEN_1 / 1000);
        _;
    }

    function test_GivenNoPoolForOneOfTheRoutesProvided()
        external
        whenCallerIsKeeper
        whenSlippageDoesNotExceedMAX_SLIPPAGE
        whenTokenToSwapIsNotTheZeroAddress
        whenTokenToSwapIsNotTargetToken
        whenRoutesAreGiven
        whenInputTokenOfFirstRouteIsTokenToSwap
        whenOutputTokenOfLastRouteIsTargetToken
        givenBalanceInTokenToSwapIsNotZero
    {
        // Ensure there is no volatile token0 <> token1 pool
        assertEq(poolFactory.getPool(address(token0), address(token1), false), address(0));

        IRouter.Route[] memory routes = new IRouter.Route[](2);
        routes[0] = IRouter.Route(address(token0), address(token1), false);
        routes[1] = IRouter.Route(address(token1), address(rewardToken), true);

        // It should revert with NoRouteFound
        vm.expectRevert(IConverter.NoRouteFound.selector);
        feeConverter.swapTokenToToken({_token: address(token0), _slippage: 500, _routes: routes});
    }

    modifier givenAPoolForAllRoutesProvided() {
        _;
    }

    function test_GivenNoQuoteForOneOfTheRoutesProvided()
        external
        whenCallerIsKeeper
        whenSlippageDoesNotExceedMAX_SLIPPAGE
        whenTokenToSwapIsNotTheZeroAddress
        whenTokenToSwapIsNotTargetToken
        whenRoutesAreGiven
        whenInputTokenOfFirstRouteIsTokenToSwap
        whenOutputTokenOfLastRouteIsTargetToken
        givenBalanceInTokenToSwapIsNotZero
        givenAPoolForAllRoutesProvided
    {
        // Create additional pool for swap
        _createPoolAndSimulateSwaps({
            tokenA: address(token0),
            tokenB: address(token1),
            stable: false,
            amountA: TOKEN_1,
            amountB: USDC_1
        });
        vm.startPrank(stakingRewardsFactory.keepers()[0]);

        IRouter.Route[] memory routes = new IRouter.Route[](2);
        routes[0] = IRouter.Route(address(token0), address(token1), false);
        routes[1] = IRouter.Route(address(token1), address(rewardToken), true);
        uint256 snapshot = vm.snapshot();

        // Simulating 0 quote from First Pool in Route
        vm.mockCall({
            callee: poolFactory.getPool(address(token0), address(token1), false),
            data: abi.encodeWithSelector(IPool.quote.selector),
            returnData: abi.encode(0)
        });
        // It should revert with NoRouteFound
        vm.expectRevert(IConverter.NoRouteFound.selector);
        feeConverter.swapTokenToToken({_token: address(token0), _slippage: 500, _routes: routes});

        // @dev Revert to Initial State and clear Mocked Calls
        vm.revertTo(snapshot);
        vm.clearMockedCalls();

        // Simulating 0 quote from Second Pool in Route
        vm.mockCall({
            callee: poolFactory.getPool(address(token1), address(rewardToken), true),
            data: abi.encodeWithSelector(IPool.quote.selector),
            returnData: abi.encode(0)
        });
        vm.expectRevert(IConverter.NoRouteFound.selector);
        // It should revert with NoRouteFound
        feeConverter.swapTokenToToken({_token: address(token0), _slippage: 500, _routes: routes});
    }

    function test_GivenAQuoteForAllRoutesProvided()
        external
        whenCallerIsKeeper
        whenSlippageDoesNotExceedMAX_SLIPPAGE
        whenTokenToSwapIsNotTheZeroAddress
        whenTokenToSwapIsNotTargetToken
        whenRoutesAreGiven
        whenInputTokenOfFirstRouteIsTokenToSwap
        whenOutputTokenOfLastRouteIsTargetToken
        givenBalanceInTokenToSwapIsNotZero
        givenAPoolForAllRoutesProvided
    {
        // Create additional pool for swap
        _createPoolAndSimulateSwaps({
            tokenA: address(token0),
            tokenB: address(token1),
            stable: false,
            amountA: TOKEN_1,
            amountB: USDC_1
        });
        address keeper = stakingRewardsFactory.keepers()[0];

        vm.startPrank(keeper);
        IRouter.Route[] memory routes = new IRouter.Route[](2);
        routes[0] = IRouter.Route(address(token0), address(token1), false);
        routes[1] = IRouter.Route(address(token1), address(rewardToken), true);

        address pool1 = poolFactory.getPool(address(token0), address(token1), false);
        address pool2 = poolFactory.getPool(address(token1), address(rewardToken), true);

        assertGt(token0.balanceOf(address(feeConverter)), 0);
        assertEq(rewardToken.balanceOf(address(feeConverter)), 0);
        assertEq(token0.allowance(address(feeConverter), address(router)), 0);
        assertEq(feeConverter.amountEarned(VelodromeTimeLibrary.epochStart(block.timestamp)), 0);

        // It should execute swap via Router
        vm.expectEmit(true, true, false, false, pool1);
        emit IPool.Swap({
            sender: address(router),
            to: address(pool2),
            amount0In: 0,
            amount1In: 0,
            amount0Out: 0,
            amount1Out: 0
        });
        vm.expectEmit(true, true, false, false, pool2);
        emit IPool.Swap({
            sender: address(router),
            to: address(feeConverter),
            amount0In: 0,
            amount1In: 0,
            amount0Out: 0,
            amount1Out: 0
        });
        // It should emit a {SwapTokenToToken} event
        vm.expectEmit(true, true, false, false, address(feeConverter));
        emit IConverter.SwapTokenToToken({
            sender: address(keeper),
            token: address(token0),
            amountIn: token0.balanceOf(address(feeConverter)),
            amountOut: 0,
            routes: routes
        });
        feeConverter.swapTokenToToken({_token: address(token0), _slippage: 500, _routes: routes});

        // It should swap all existing balance in input token to target token
        assertEq(token0.balanceOf(address(feeConverter)), 0);
        assertGt(rewardToken.balanceOf(address(feeConverter)), 0);
        // It should update the value of amountEarned
        assertEq(
            feeConverter.amountEarned(VelodromeTimeLibrary.epochStart(block.timestamp)),
            rewardToken.balanceOf(address(feeConverter))
        );

        // It should use all existing allowance in Swap
        assertEq(token0.allowance(address(feeConverter), address(router)), 0);
    }
}
