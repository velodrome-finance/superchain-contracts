// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract NotifyRewardWithoutClaimIntegrationConcreteTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: leafId});

        uint256 amount = TOKEN_1 * 1000;
        deal({token: address(leafXVelo), to: address(leafMessageModule), give: amount});

        vm.prank(address(leafMessageModule));
        leafXVelo.approve({spender: address(leafGauge), value: amount});
    }

    function test_WhenTheCallerIsNotTheModule() external {
        // It should revert with NotModule
        vm.prank(users.charlie);
        vm.expectRevert(ILeafGauge.NotModule.selector);
        leafGauge.notifyRewardWithoutClaim({_amount: TOKEN_1 * 1000});
    }

    modifier whenTheCallerIsTheModule() {
        vm.startPrank(address(leafMessageModule));
        _;
    }

    function test_WhenTheAmountIsZero() external whenTheCallerIsTheModule {
        // It should revert with ZeroAmount
        vm.expectRevert(ILeafGauge.ZeroAmount.selector);
        leafGauge.notifyRewardWithoutClaim({_amount: 0});
    }

    function test_WhenTheAmountIsGreaterThanZeroAndSmallerThanTheTimeUntilTheNextTimestamp()
        external
        whenTheCallerIsTheModule
    {
        // It should revert with ZeroRewardRate
        vm.expectRevert(ILeafGauge.ZeroRewardRate.selector);
        leafGauge.notifyRewardWithoutClaim({_amount: WEEK - 1});
    }

    modifier whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish()
        external
        whenTheCallerIsTheModule
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp
    {
        // It should update rewardPerTokenStored
        // It should deposit the amount of reward token
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1000;
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: amount});
        leafGauge.notifyRewardWithoutClaim({_amount: amount});

        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(leafStartTime), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish()
        external
        whenTheCallerIsTheModule
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp
    {
        // It should update rewardPerTokenStored
        // It should deposit the amount of reward token
        // It should update the reward rate, including any existing rewards
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1000;
        deal({token: address(leafXVelo), to: address(leafMessageModule), give: amount * 2});
        leafXVelo.approve({spender: address(leafGauge), value: amount * 2});

        // inital deposit of partial amount
        leafGauge.notifyRewardWithoutClaim({_amount: amount});

        skipTime(WEEK / 7 * 5);

        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: amount});
        leafGauge.notifyRewardWithoutClaim({_amount: amount});

        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount * 2);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = WEEK * 2 / 7;
        uint256 rewardRate = ((amount / WEEK) * timeUntilNext + amount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(leafStartTime), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK / 7 * 2);
    }
}
