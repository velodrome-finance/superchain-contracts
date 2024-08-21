// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract NotifyRewardAmountIntegrationConcreteTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: leafId});

        uint256 amount = TOKEN_1 * 1000;
        deal({token: address(leafXVelo), to: address(leafBridge), give: amount});

        vm.prank(address(leafBridge));
        leafXVelo.approve({spender: address(leafGauge), value: amount});
    }

    function test_WhenTheCallerIsNotBridge() external {
        // It should revert with NotBridge
        vm.prank(users.charlie);
        vm.expectRevert(ILeafGauge.NotBridge.selector);
        leafGauge.notifyRewardAmount({_amount: TOKEN_1 * 1000});
    }

    modifier whenTheCallerIsBridge() {
        vm.startPrank(address(leafBridge));
        _;
    }

    function test_WhenTheAmountIsZero() external whenTheCallerIsBridge {
        // It should revert with ZeroAmount
        vm.expectRevert(ILeafGauge.ZeroAmount.selector);
        leafGauge.notifyRewardAmount({_amount: 0});
    }

    function test_WhenTheAmountIsGreaterThanZeroAndSmallerThanTheTimeUntilTheNextTimestamp()
        external
        whenTheCallerIsBridge
    {
        // It should revert with ZeroRewardRate
        vm.expectRevert(ILeafGauge.ZeroRewardRate.selector);
        leafGauge.notifyRewardAmount({_amount: WEEK - 1});
    }

    modifier whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish()
        external
        whenTheCallerIsBridge
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp
    {
        // It should claim fees from pool
        // It should update rewardPerTokenStored
        // It should deposit the amount of reward token
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1000;
        vm.expectCall(address(leafPool), abi.encodeCall(IPool.claimFees, ()));
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafBridge), _amount: amount});
        leafGauge.notifyRewardAmount({_amount: amount});

        assertEq(leafXVelo.balanceOf(address(leafBridge)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(leafStartTime), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish()
        external
        whenTheCallerIsBridge
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp
    {
        // It should claim fees from pool
        // It should update rewardPerTokenStored
        // It should deposit the amount of reward token
        // It should update the reward rate, including any existing rewards
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1000;
        deal({token: address(leafXVelo), to: address(leafBridge), give: amount * 2});
        leafXVelo.approve({spender: address(leafGauge), value: amount * 2});

        // inital deposit of partial amount
        leafGauge.notifyRewardAmount({_amount: amount});

        skipTime(WEEK / 7 * 5);

        vm.expectCall(address(leafPool), abi.encodeCall(IPool.claimFees, ()));
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafBridge), _amount: amount});
        leafGauge.notifyRewardAmount({_amount: amount});

        assertEq(leafXVelo.balanceOf(address(leafBridge)), 0);
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
