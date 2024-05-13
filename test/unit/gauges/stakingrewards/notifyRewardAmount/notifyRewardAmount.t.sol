// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../../BaseFixture.sol";

contract NotifyRewardAmountTest is BaseFixture {
    Pool public pool;
    StakingRewards public stakingRewards;

    function setUp() public override {
        super.setUp();

        pool = Pool(poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        stakingRewards = StakingRewards(
            stakingRewardsFactory.createStakingRewards({_pool: address(pool), _rewardToken: address(rewardToken)})
        );

        addLiquidityToPool(users.alice, address(token0), address(token1), true, TOKEN_1, USDC_1);
        vm.startPrank(users.alice);
        deal(address(rewardToken), users.alice, TOKEN_1 * 1_000_000);
        rewardToken.approve(address(stakingRewards), type(uint256).max);
    }

    function test_WhenAmountIsZero() external {
        // It should revert with ZeroAmount
        vm.expectRevert(IStakingRewards.ZeroAmount.selector);
        stakingRewards.notifyRewardAmount({_amount: 0});
    }

    function test_WhenAmountIsGreaterThanZeroAndSmallerThanTheTimeUntilTheNextTimestamp() external {
        // It should revert with ZeroRewardRate
        vm.expectRevert(IStakingRewards.ZeroRewardRate.selector);
        stakingRewards.notifyRewardAmount({_amount: WEEK - 1});
    }

    modifier whenTheAmountIsGreaterThanTheTimeUntilTheNextTimestamp() {
        _;
    }

    modifier whenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish() {
        _;
    }

    function test_GivenThereAreNoConvertedFeesInConverter()
        external
        whenTheAmountIsGreaterThanTheTimeUntilTheNextTimestamp
        whenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish
    {
        // It should update rewardPerTokenStored
        // It should transfer funds from the caller to the contract
        // It should set a new reward rate
        // It should cache the reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: WEEK});
        stakingRewards.notifyRewardAmount({_amount: WEEK});

        assertEq(stakingRewards.rewardPerTokenStored(), 0);
        assertEq(rewardToken.balanceOf(address(stakingRewards)), WEEK);
        assertEq(stakingRewards.rewardRate(), 1);
        assertEq(stakingRewards.rewardRateByEpoch(604800), 1);
        assertEq(stakingRewards.lastUpdateTime(), block.timestamp);
        assertEq(stakingRewards.periodFinish(), block.timestamp + WEEK);
    }

    function test_GivenThereAreConvertedFeesInConverter()
        external
        whenTheAmountIsGreaterThanTheTimeUntilTheNextTimestamp
        whenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish
    {
        // It should update rewardPerTokenStored
        // It should transfer funds from the caller to the contract
        // It should transfer any converted fees from converter to the contract
        // It should set a new reward rate
        // It should cache the reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1000;
        address feeConverter = stakingRewards.feeConverter();
        deal(address(rewardToken), feeConverter, amount);

        vm.expectEmit(feeConverter);
        emit IConverter.Compound({balanceCompounded: amount});
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: WEEK + amount});
        stakingRewards.notifyRewardAmount({_amount: WEEK});

        uint256 rewardRate = (WEEK + amount) / WEEK;

        assertEq(stakingRewards.rewardPerTokenStored(), 0);
        assertEq(rewardToken.balanceOf(feeConverter), 0);
        assertEq(rewardToken.balanceOf(address(stakingRewards)), WEEK + amount);
        assertEq(stakingRewards.rewardRate(), rewardRate);
        assertEq(stakingRewards.rewardRateByEpoch(604800), rewardRate);
        assertEq(stakingRewards.lastUpdateTime(), block.timestamp);
        assertEq(stakingRewards.periodFinish(), block.timestamp + WEEK);
    }

    modifier whenTheCurrentTimestampIsLessThanPeriodFinish() {
        _;
    }

    function test_WhenAmountIsLessThanLeftoverRewards()
        external
        whenTheAmountIsGreaterThanTheTimeUntilTheNextTimestamp
        whenTheCurrentTimestampIsLessThanPeriodFinish
    {
        // It should revert with InsufficientAmount
        uint256 amount = TOKEN_1 * 1_000;
        stakingRewards.notifyRewardAmount({_amount: amount});

        skip(WEEK * 5 / 7);

        uint256 leftover = (amount / WEEK) * (WEEK * 2 / 7);
        vm.expectRevert(IStakingRewards.InsufficientAmount.selector);
        stakingRewards.notifyRewardAmount({_amount: leftover - 1});
    }

    modifier whenAmountIsGreaterThanOrEqualToLeftoverRewards() {
        _;
    }

    function test_GivenThereAreNoConvertedFundsInConverter()
        external
        whenTheAmountIsGreaterThanTheTimeUntilTheNextTimestamp
        whenTheCurrentTimestampIsLessThanPeriodFinish
        whenAmountIsGreaterThanOrEqualToLeftoverRewards
    {
        // It should update rewardPerTokenStored
        // It should transfer funds from the caller to the contract
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1_000;
        stakingRewards.notifyRewardAmount({_amount: amount});

        skip(WEEK * 5 / 7);

        uint256 amount2 = (amount / WEEK) * (WEEK * 2 / 7); // leftover calculation
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: amount2});
        stakingRewards.notifyRewardAmount({_amount: amount2});

        assertEq(stakingRewards.rewardPerTokenStored(), 0);
        assertEq(rewardToken.balanceOf(address(stakingRewards)), amount + amount2);
        assertEq(stakingRewards.rewardRate(), (amount * 2 / 7 + amount2) / WEEK);
        assertEq(stakingRewards.rewardRateByEpoch(604800), (amount * 2 / 7 + amount2) / WEEK);
        assertEq(stakingRewards.lastUpdateTime(), block.timestamp);
        assertEq(stakingRewards.periodFinish(), block.timestamp + WEEK);
    }

    function test_GivenThereAreConvertedFundsInConverter()
        external
        whenTheAmountIsGreaterThanTheTimeUntilTheNextTimestamp
        whenTheCurrentTimestampIsLessThanPeriodFinish
        whenAmountIsGreaterThanOrEqualToLeftoverRewards
    {
        // It should update rewardPerTokenStored
        // It should transfer funds from the caller to the contract
        // It should transfer any converted fees from converter to the contract
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1000;
        stakingRewards.notifyRewardAmount({_amount: amount});

        skip(WEEK * 5 / 7);

        uint256 converterAmount = TOKEN_1 * 500;
        address feeConverter = stakingRewards.feeConverter();
        deal(address(rewardToken), feeConverter, converterAmount);

        uint256 amount2 = (amount / WEEK) * (WEEK * 2 / 7); // leftover calculation
        vm.expectEmit(feeConverter);
        emit IConverter.Compound({balanceCompounded: converterAmount});
        vm.expectEmit(address(stakingRewards));
        emit IStakingRewards.NotifyReward({from: users.alice, amount: amount2 + converterAmount});
        stakingRewards.notifyRewardAmount({_amount: amount2});

        assertEq(stakingRewards.rewardPerTokenStored(), 0);
        assertEq(rewardToken.balanceOf(feeConverter), 0);
        assertEq(rewardToken.balanceOf(address(stakingRewards)), amount + amount2 + converterAmount);
        assertEq(stakingRewards.rewardRate(), (amount * 2 / 7 + amount2 + converterAmount) / WEEK);
        assertEq(stakingRewards.rewardRateByEpoch(604800), (amount * 2 / 7 + amount2 + converterAmount) / WEEK);
        assertEq(stakingRewards.lastUpdateTime(), block.timestamp);
        assertEq(stakingRewards.periodFinish(), block.timestamp + WEEK);
    }
}
