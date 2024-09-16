// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGauge.t.sol";

contract NotifyRewardAmountIntegrationConcreteTest is RootGaugeTest {
    function setUp() public override {
        super.setUp();

        // use users.alice as tx.origin
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});
    }

    function test_WhenTheCallerIsNotVoter() external {
        // It should revert with NotVoter
        vm.prank(users.charlie);
        vm.expectRevert(IRootGauge.NotVoter.selector);
        rootGauge.notifyRewardAmount({_amount: 0});
    }

    modifier whenTheCallerIsVoter() {
        vm.prank(address(mockVoter));
        _;
    }

    function test_WhenTheAmountIsZero() external whenTheCallerIsVoter {
        // It should revert with ZeroAmount
        vm.expectRevert(IRootGauge.ZeroAmount.selector);
        rootGauge.notifyRewardAmount({_amount: 0});
    }

    function test_WhenTheAmountIsGreaterThanZeroAndSmallerThanTheTimeInAWeek() external whenTheCallerIsVoter {
        // It should revert with ZeroRewardRate
        uint256 amount = WEEK - 1;
        vm.expectRevert(IRootGauge.ZeroRewardRate.selector);
        rootGauge.notifyRewardAmount({_amount: amount});
    }

    modifier whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeInAWeek() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish()
        external
        whenTheCallerIsVoter
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeInAWeek
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
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: amount});

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: amount});
        rootGauge.notifyRewardAmount({_amount: amount});

        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: amount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish()
        external
        whenTheCallerIsVoter
        whenTheAmountIsGreaterThanZeroAndGreaterThanOrEqualToTheTimeInAWeek
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
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 2});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE * 2});

        uint256 amount = TOKEN_1 * 1_000;
        setLimits({_rootMintingLimit: amount * 2, _leafMintingLimit: amount * 2});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: amount * 2});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: amount * 2});

        // inital deposit of partial amount
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        rootGauge.notifyRewardAmount({_amount: amount});
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        skipTime(WEEK / 7 * 5);

        vm.selectFork({forkId: rootId});
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: amount});
        rootGauge.notifyRewardAmount({_amount: amount});

        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: amount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount * 2);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = WEEK * 2 / 7;
        uint256 rewardRate = ((amount / WEEK) * timeUntilNext + amount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK / 7 * 2);
    }
}
