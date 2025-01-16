// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGauge.t.sol";

contract NotifyRewardWithoutClaimIntegrationConcreteTest is RootGaugeTest {
    function setUp() public override {
        super.setUp();

        // use users.alice as tx.origin
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});
    }

    function test_WhenTheCallerIsNotNotifyAdmin() external {
        // It should revert with {NotAuthorized}
        vm.prank(users.charlie);
        vm.expectRevert(IRootGauge.NotAuthorized.selector);
        rootGauge.notifyRewardWithoutClaim({_amount: 0});
    }

    modifier whenTheCallerIsNotifyAdmin() {
        vm.prank(users.owner);
        _;
    }

    function test_WhenTheAmountIsSmallerThanTheTimeInAWeek() external whenTheCallerIsNotifyAdmin {
        // It should revert with {ZeroRewardRate}
        uint256 amount = WEEK - 1;
        vm.expectRevert(IRootGauge.ZeroRewardRate.selector);
        rootGauge.notifyRewardWithoutClaim({_amount: amount});
    }

    modifier whenTheAmountIsGreaterThanOrEqualToTheTimeInAWeek() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish()
        external
        whenTheCallerIsNotifyAdmin
        whenTheAmountIsGreaterThanOrEqualToTheTimeInAWeek
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
        setLimits({_rootBufferCap: amount * 2, _leafBufferCap: amount * 2});

        deal({token: address(rootRewardToken), to: users.owner, give: amount});
        vm.prank(users.owner);
        rootRewardToken.approve({spender: address(rootGauge), value: amount});

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));

        vm.prank({msgSender: users.owner, txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: users.owner, _amount: amount});
        rootGauge.notifyRewardWithoutClaim({_amount: amount});

        assertEq(rootRewardToken.balanceOf(users.owner), 0);
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
        whenTheCallerIsNotifyAdmin
        whenTheAmountIsGreaterThanOrEqualToTheTimeInAWeek
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
        setLimits({_rootBufferCap: amount * 4, _leafBufferCap: amount * 4});

        deal({token: address(rootRewardToken), to: users.owner, give: amount * 2});
        vm.prank(users.owner);
        rootRewardToken.approve({spender: address(rootGauge), value: amount * 2});

        // inital deposit of partial amount
        vm.prank({msgSender: users.owner, txOrigin: users.alice});
        rootGauge.notifyRewardWithoutClaim({_amount: amount});
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        skipTime(WEEK / 7 * 5);

        vm.selectFork({forkId: rootId});
        vm.prank({msgSender: users.owner, txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: users.owner, _amount: amount});
        rootGauge.notifyRewardWithoutClaim({_amount: amount});

        assertEq(rootRewardToken.balanceOf(users.owner), 0);
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

    function testGas_notifyRewardWithoutClaim()
        external
        whenTheCallerIsNotifyAdmin
        whenTheAmountIsGreaterThanOrEqualToTheTimeInAWeek
    {
        uint256 amount = TOKEN_1 * 1_000;
        setLimits({_rootBufferCap: amount * 2, _leafBufferCap: amount * 2});

        deal({token: address(rootRewardToken), to: users.owner, give: amount});
        vm.prank(users.owner);
        rootRewardToken.approve({spender: address(rootGauge), value: amount});

        vm.prank({msgSender: users.owner, txOrigin: users.alice});
        rootGauge.notifyRewardWithoutClaim({_amount: amount});
        vm.snapshotGasLastCall("RootGauge_notifyRewardWithoutClaim");
    }
}
