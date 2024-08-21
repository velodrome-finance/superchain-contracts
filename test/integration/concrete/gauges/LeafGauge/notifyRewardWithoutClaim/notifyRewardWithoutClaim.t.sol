// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract NotifyRewardWithoutClaimIntegrationConcreteTest is BaseForkFixture {
    address public notifyAdmin;

    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: leafId});

        uint256 amount = TOKEN_1 * 1000;
        notifyAdmin = leafGaugeFactory.notifyAdmin();
        deal({token: address(leafXVelo), to: notifyAdmin, give: amount});

        vm.prank(notifyAdmin);
        leafXVelo.approve({spender: address(leafGauge), value: amount});
    }

    function test_WhenTheCallerIsNotNotifyAdmin() external {
        // It should revert with NotAuthorized
        vm.prank(users.charlie);
        vm.expectRevert(ILeafGauge.NotAuthorized.selector);
        leafGauge.notifyRewardWithoutClaim({_amount: TOKEN_1 * 1000});
    }

    modifier whenTheCallerIsNotifyAdmin() {
        vm.startPrank(notifyAdmin);
        _;
    }

    function test_WhenTheAmountIsZero() external whenTheCallerIsNotifyAdmin {
        // It should revert with ZeroAmount
        vm.expectRevert(ILeafGauge.ZeroAmount.selector);
        leafGauge.notifyRewardWithoutClaim({_amount: 0});
    }

    function test_WhenTheAmountIsGreaterThanZeroAndSmallerThanTheTimeUntilTheNextTimestamp()
        external
        whenTheCallerIsNotifyAdmin
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
        whenTheCallerIsNotifyAdmin
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
        emit ILeafGauge.NotifyReward({_sender: notifyAdmin, _amount: amount});
        leafGauge.notifyRewardWithoutClaim({_amount: amount});

        assertEq(leafXVelo.balanceOf(notifyAdmin), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(leafStartTime), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish()
        external
        whenTheCallerIsNotifyAdmin
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
        deal({token: address(leafXVelo), to: notifyAdmin, give: amount * 2});
        leafXVelo.approve({spender: address(leafGauge), value: amount * 2});

        // inital deposit of partial amount
        leafGauge.notifyRewardWithoutClaim({_amount: amount});

        skipTime(WEEK / 7 * 5);

        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: notifyAdmin, _amount: amount});
        leafGauge.notifyRewardWithoutClaim({_amount: amount});

        assertEq(leafXVelo.balanceOf(notifyAdmin), 0);
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
