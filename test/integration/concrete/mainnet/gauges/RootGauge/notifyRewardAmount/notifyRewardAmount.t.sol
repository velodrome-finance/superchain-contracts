// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract NotifyRewardAmountIntegrationConcreteTest is BaseForkFixture {
    function test_WhenTheCallerIsNotVoter() external {
        // It should revert with NotVoter
    }

    modifier whenTheCallerIsVoter() {
        _;
    }

    function test_WhenTheAmountIsZero() external whenTheCallerIsVoter {
        // It should revert with ZeroAmount
    }

    function test_WhenTheAmountIsGreaterThanZeroAndSmallerThanTheTimeUntilTheNextTimestamp()
        external
        whenTheCallerIsVoter
    {
        // It should revert with ZeroRewardRate
    }

    modifier whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish()
        external
        whenTheCallerIsVoter
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp
    {
        // It should wrap the tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1_000;
        setLimits({_rootMintingLimit: amount, _leafMintingLimit: amount});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: amount});
        vm.startPrank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: amount});

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));

        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: amount});
        rootGauge.notifyRewardAmount({_amount: amount});

        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafBridge), _amount: amount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(rootStartTime), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish()
        external
        whenTheCallerIsVoter
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeUntilTheNextTimestamp
    {
        // It should wrap the tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate, including any existing rewards
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1_000;
        setLimits({_rootMintingLimit: amount * 2, _leafMintingLimit: amount * 2});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: amount * 2});
        vm.startPrank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: amount * 2});

        // inital deposit of partial amount
        rootGauge.notifyRewardAmount({_amount: amount});
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        skipTime(WEEK / 7 * 5);

        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: amount});
        rootGauge.notifyRewardAmount({_amount: amount});

        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafBridge), _amount: amount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount * 2);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = WEEK * 2 / 7;
        uint256 rewardRate = ((amount / WEEK) * timeUntilNext + amount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(rootStartTime), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK / 7 * 2);
    }
}
