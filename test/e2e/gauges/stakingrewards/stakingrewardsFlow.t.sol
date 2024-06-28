// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../unit/concrete/gauges/converter/Converter.t.sol";

contract StakingRewardsFlowTest is ConverterTest {
    uint256 public constant MINIMUM_OBSERVATIONS = 3;
    uint256 public constant notifyAmount = TOKEN_1 * 1_000;

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
        _simulateMultipleSwaps({
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            stable: stable,
            amountA: amountA,
            amountB: amountB,
            swapCount: MINIMUM_OBSERVATIONS,
            timeskip: 1801
        });
    }

    /// @dev Helper to Simulate Multiple Swaps and Observations
    function _simulateMultipleSwaps(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountA,
        uint256 amountB,
        uint256 swapCount,
        uint256 timeskip
    ) internal {
        vm.startPrank(users.bob);
        for (uint256 i = 0; i < swapCount; i++) {
            if (i % 2 == 0) {
                _simulateSwap({
                    tokenIn: address(tokenA),
                    tokenOut: address(tokenB),
                    stable: stable,
                    amount: amountA,
                    timeskip: timeskip
                });
            } else {
                _simulateSwap({
                    tokenIn: address(tokenB),
                    tokenOut: address(tokenA),
                    stable: stable,
                    amount: amountB,
                    timeskip: timeskip
                });
            }
        }
        vm.stopPrank();
    }

    /// @dev Helper to Simulate a single Swap and write an Observation
    function _simulateSwap(address tokenIn, address tokenOut, bool stable, uint256 amount, uint256 timeskip) internal {
        skip(timeskip);
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

    function test_StakingRewardslow() public {
        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                         EPOCH X                            */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
        // In this Epoch:
        // There will be the first Notify and Deposit into StakingRewards
        // There are no Fees to be claimed from Keeper
        // Swaps are simulated for fees to accrue
        // There are no Fees to be swapped in Converter
        // Keeper should swap all fees claimed from past epoch
        // Alice should claim rewards available after swaps
        skipToNextEpoch(0);

        // Alice deposits
        vm.startPrank(users.alice);
        uint256 depositAmount = pool.balanceOf(users.alice);
        pool.approve(address(stakingRewards), depositAmount);
        stakingRewards.deposit(depositAmount, users.alice);

        assertEq(stakingRewards.earned(users.alice), 0);
        assertEq(stakingRewards.totalSupply(), depositAmount);
        assertEq(stakingRewards.balanceOf(users.alice), depositAmount);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                     Reward Notification                    */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        // No rewards in StakingRewards yet
        assertEq(rewardToken.balanceOf(address(stakingRewards)), 0);

        // First Notify
        deal(address(rewardToken), users.alice, notifyAmount);
        rewardToken.approve(address(stakingRewards), notifyAmount);
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: notifyAmount});
        stakingRewards.notifyRewardAmount({_amount: notifyAmount});

        // The notified tokens are distributed to the Staking Rewards contract
        assertEq(rewardToken.balanceOf(address(stakingRewards)), notifyAmount);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                      Simulate Swaps                        */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        // Time passes
        skip(WEEK * 3 / 7);

        // Simulate Swaps for Fees to accrue
        _simulateMultipleSwaps({
            tokenA: address(token0),
            tokenB: address(token1),
            stable: true,
            amountA: TOKEN_1 * 1_000,
            amountB: USDC_1 * 1_000,
            swapCount: 5000, // 5000 swaps = 5000 skipped minutes
            timeskip: 60
        });

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                        Get Reward                          */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        uint256 timeElapsed = block.timestamp - VelodromeTimeLibrary.epochStart(block.timestamp);
        uint256 earned = stakingRewards.earned(users.alice);
        assertApproxEqAbs(earned, stakingRewards.rewardRate() * timeElapsed, 1);
        uint256 oldBal = rewardToken.balanceOf(users.alice);

        // Partial Reward claiming during Epoch X
        vm.prank(users.alice);
        stakingRewards.getReward(users.alice);

        assertApproxEqAbs(rewardToken.balanceOf(users.alice) - oldBal, earned, 1);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                         EPOCH X+1                          */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
        // In this Epoch:
        // Alice claims existing rewards
        // There will be a second notify
        // Keeper should claim any fees accrued throughout past week
        // More swaps for more fees to accrue
        // Keeper should swap all fees claimed from past epoch
        skipToNextEpoch(0);

        // Claim all existing Rewards in the beginning of Epoch X+1
        vm.prank(users.alice);
        stakingRewards.getReward(users.alice);

        assertApproxEqAbs(rewardToken.balanceOf(address(stakingRewards)), 0, 1e6);
        assertApproxEqAbs(rewardToken.balanceOf(users.alice) - oldBal, notifyAmount, 1e6);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                     Notify Rewards                         */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        vm.startPrank(users.alice); // Reset prank after swap simulations
        deal(address(rewardToken), users.alice, notifyAmount);
        rewardToken.approve(address(stakingRewards), notifyAmount);

        // Second Notify
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: notifyAmount});
        stakingRewards.notifyRewardAmount({_amount: notifyAmount});

        // The notified tokens are distributed to the Staking Rewards contract
        assertApproxEqAbs(rewardToken.balanceOf(address(stakingRewards)), notifyAmount, 1e6);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                  Keeper Claim Fees                         */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        address poolFees = pool.poolFees();
        uint256 expectedFees0 = token0.balanceOf(poolFees);
        uint256 expectedFees1 = token1.balanceOf(poolFees);
        address keeper = stakingRewardsFactory.keepers()[0];

        // Keeper should Claim Fees in Converter
        // Any claimed Fees will be swapped throughout the week in converter
        vm.expectEmit(true, false, false, false, address(stakingRewards));
        emit IStakingRewards.ClaimFees({claimed0: expectedFees0, claimed1: expectedFees1});
        vm.startPrank(keeper);
        feeConverter.claimFees();

        // Fees should be sent to Converter
        assertApproxEqAbs(token0.balanceOf(poolFees), 0, 1e9); // Higher delta because 18 decimals
        assertApproxEqAbs(token1.balanceOf(poolFees), 0, 1);
        assertApproxEqAbs(token0.balanceOf(address(feeConverter)), expectedFees0, 1e9);
        assertApproxEqAbs(token1.balanceOf(address(feeConverter)), expectedFees1, 1);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                      Simulate Swaps                        */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        // More swaps to accrue this week's fees
        _simulateMultipleSwaps({
            tokenA: address(token0),
            tokenB: address(token1),
            stable: true,
            amountA: TOKEN_1 * 10_000,
            amountB: USDC_1 * 10_000,
            swapCount: 5000, // 5000 swaps = 5000 skipped minutes
            timeskip: 60
        });

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                     Keeper Swap Fees                       */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        // Keeper swaps Fees in Converter
        uint256 convertedFees = rewardToken.balanceOf(address(feeConverter));
        assertEq(convertedFees, 0);

        vm.startPrank(keeper);

        // Swap Token 0
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(token0), address(rewardToken), true);
        vm.expectEmit(true, true, false, false, address(feeConverter));
        emit IConverter.SwapTokenToToken({
            sender: address(keeper),
            token: address(token0),
            amountIn: token0.balanceOf(address(feeConverter)),
            amountOut: 0,
            routes: routes
        });
        feeConverter.swapTokenToToken({_token: address(token0), _slippage: 500, _routes: routes});

        assertEq(token0.balanceOf(address(feeConverter)), 0); // All token Balance has been swapped
        assertGt(rewardToken.balanceOf(address(feeConverter)), convertedFees); // RewardToken Balance has increased
        convertedFees = rewardToken.balanceOf(address(feeConverter));

        // Swap Token 1
        routes[0] = IRouter.Route(address(token1), address(rewardToken), true);
        vm.expectEmit(true, true, false, false, address(feeConverter));
        emit IConverter.SwapTokenToToken({
            sender: address(keeper),
            token: address(token1),
            amountIn: token1.balanceOf(address(feeConverter)),
            amountOut: 0,
            routes: routes
        });
        feeConverter.swapTokenToToken({_token: address(token1), _slippage: 500, _routes: routes});

        assertEq(token1.balanceOf(address(feeConverter)), 0);
        assertGt(rewardToken.balanceOf(address(feeConverter)), convertedFees); // RewardToken Balance has increased
        convertedFees = rewardToken.balanceOf(address(feeConverter));

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                        Get Reward                          */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        timeElapsed = block.timestamp - (stakingRewards.periodFinish() - WEEK);
        earned = stakingRewards.earned(users.alice);
        assertApproxEqAbs(earned, stakingRewards.rewardRate() * timeElapsed, 1);
        oldBal = rewardToken.balanceOf(users.alice);

        // Partial Reward claiming during Epoch X + 1
        vm.startPrank(users.alice);
        stakingRewards.getReward(users.alice);

        assertApproxEqAbs(rewardToken.balanceOf(users.alice) - oldBal, earned, 1);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                         EPOCH X+2                          */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
        // On This Epoch:
        // There is the third Notify
        // Converted fees are also included in this notify
        // Keeper should also claim any fees accrued throughout past week
        uint256 timeUntilNextWeek = stakingRewards.periodFinish() - block.timestamp;
        skip(timeUntilNextWeek / 2); // avoid skipping to a new week

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                     Notify Rewards                         */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        uint256 earnedBeforeNotify = stakingRewards.earned(users.alice);

        deal(address(rewardToken), users.alice, notifyAmount);
        rewardToken.approve(address(stakingRewards), notifyAmount);

        // Third Notify
        // Any converted Fees should be redeposited into the StakingRewards contract
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: notifyAmount + convertedFees});
        stakingRewards.notifyRewardAmount({_amount: notifyAmount});

        // Notified tokens along with any Converted Fees are distributed to the Staking Rewards contract
        assertApproxEqAbs(
            rewardToken.balanceOf(address(stakingRewards)), notifyAmount * 2 + convertedFees - earned, 1e6
        );
        assertEq(rewardToken.balanceOf(address(feeConverter)), 0);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                  Keeper Claim Fees                         */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        expectedFees0 = token0.balanceOf(poolFees);
        expectedFees1 = token1.balanceOf(poolFees);

        assertApproxEqAbs(token0.balanceOf(poolFees), expectedFees0, 1e9);
        assertApproxEqAbs(token1.balanceOf(poolFees), expectedFees1, 1);
        assertApproxEqAbs(token0.balanceOf(address(feeConverter)), 0, 1e9); // Higher delta because 18 decimals
        assertApproxEqAbs(token1.balanceOf(address(feeConverter)), 0, 1);

        // Keeper should Claim Fees in Converter
        // Any claimed Fees should be swapped throughout the week in converter
        vm.startPrank(keeper);
        vm.expectEmit(true, false, false, false, address(stakingRewards));
        emit IStakingRewards.ClaimFees({claimed0: expectedFees0, claimed1: expectedFees1});
        feeConverter.claimFees();

        // Fees should be sent to Converter
        assertApproxEqAbs(token0.balanceOf(poolFees), 0, 1e10); // Higher delta because 18 decimals
        assertApproxEqAbs(token1.balanceOf(poolFees), 0, 1e2);
        assertApproxEqAbs(token0.balanceOf(address(feeConverter)), expectedFees0, 1e10);
        assertApproxEqAbs(token1.balanceOf(address(feeConverter)), expectedFees1, 1e2);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                        Get Reward                          */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        timeUntilNextWeek = stakingRewards.periodFinish() - block.timestamp;
        skip(timeUntilNextWeek / 3); // avoid skipping to a new week

        timeElapsed = block.timestamp - (stakingRewards.periodFinish() - WEEK);
        uint256 oldEarned = earned; // caching old value for last getReward call
        earned = stakingRewards.earned(users.alice);

        // earned before notify is kept
        assertApproxEqAbs(earned, stakingRewards.rewardRate() * timeElapsed + earnedBeforeNotify, 1);
        oldBal = rewardToken.balanceOf(users.alice);

        // Partial Reward claiming during Epoch X + 2
        vm.startPrank(users.alice);
        stakingRewards.getReward(users.alice);

        assertApproxEqAbs(rewardToken.balanceOf(users.alice) - oldBal, earned, 1);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                     Notify Rewards                         */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, notifyAmount);
        rewardToken.approve(address(stakingRewards), notifyAmount);
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.owner, amount: notifyAmount});
        stakingRewards.notifyRewardMatch({_amount: notifyAmount});

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
        /*                        Get Reward                          */
        /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

        skip(WEEK - timeElapsed); // Skip remaining time to claim leftover emissions

        // Remaining Staking Rewards balance is claimable
        assertApproxEqAbs(stakingRewards.earned(users.alice), rewardToken.balanceOf(address(stakingRewards)), 1e7);

        // Full Reward claiming during Epoch X + 2
        vm.startPrank(users.alice);
        stakingRewards.getReward(users.alice);

        // Claims amounts from 2 notifies + previously converted fees
        assertApproxEqAbs(rewardToken.balanceOf(users.alice), notifyAmount * 3 + convertedFees - oldEarned, 1e6);
        assertApproxEqAbs(rewardToken.balanceOf(address(stakingRewards)), 0, 1e7);
    }
}
