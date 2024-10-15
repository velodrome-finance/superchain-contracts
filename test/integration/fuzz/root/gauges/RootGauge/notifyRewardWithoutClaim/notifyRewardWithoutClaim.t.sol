// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGauge.t.sol";

contract NotifyRewardWithoutClaimIntegrationFuzzTest is RootGaugeTest {
    address public notifyAdmin;

    function setUp() public virtual override {
        super.setUp();

        notifyAdmin = rootGaugeFactory.notifyAdmin();
        // use users.alice as tx.origin
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});

        vm.selectFork({forkId: leafId});
        leafStartTime = block.timestamp;
        vm.selectFork({forkId: rootId});
        rootStartTime = block.timestamp;
    }

    function testFuzz_WhenTheCallerIsNotNotifyAdmin(address _caller) external {
        // It should revert with NotAuthorized
        vm.assume(_caller != notifyAdmin);

        vm.prank(_caller);
        vm.expectRevert(IRootGauge.NotAuthorized.selector);
        rootGauge.notifyRewardWithoutClaim({_amount: TOKEN_1 * 1000});
    }

    modifier whenTheCallerIsNotifyAdmin() {
        vm.startPrank({msgSender: notifyAdmin, txOrigin: users.alice});
        _;
    }

    function testFuzz_WhenTheAmountIsSmallerThanTheTimeInWeek(uint256 _amount) external whenTheCallerIsNotifyAdmin {
        // It should revert with ZeroRewardRate
        _amount = bound(_amount, 1, WEEK - 1);

        vm.expectRevert(IRootGauge.ZeroRewardRate.selector);
        rootGauge.notifyRewardWithoutClaim({_amount: _amount});
    }

    modifier whenTheAmountIsGreaterThanOrEqualToTheTimeInAWeek() {
        _;
    }

    function testFuzz_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish(uint256 _amount)
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
        vm.warp({newTimestamp: leafStartTime});

        _amount = bound(_amount, WEEK, MAX_BUFFER_CAP / 2);
        uint256 bufferCap = Math.max(_amount * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        deal({token: address(rootRewardToken), to: notifyAdmin, give: _amount});
        vm.prank(notifyAdmin);
        rootRewardToken.approve({spender: address(rootGauge), value: _amount});

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));

        vm.prank({msgSender: notifyAdmin, txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: notifyAdmin, _amount: _amount});
        rootGauge.notifyRewardWithoutClaim({_amount: _amount});

        assertEq(rootRewardToken.balanceOf(notifyAdmin), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});

        vm.warp({newTimestamp: leafStartTime});

        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: _amount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), _amount);

        assertEq(block.timestamp, leafStartTime);
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), _amount / timeUntilNext);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), _amount / timeUntilNext);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + timeUntilNext);
    }

    function testFuzz_WhenTheCurrentTimestampIsLessThanPeriodFinish(
        uint256 _initialAmount,
        uint256 _amount,
        uint256 _timeskip
    ) external whenTheCallerIsNotifyAdmin whenTheAmountIsGreaterThanOrEqualToTheTimeInAWeek {
        // It should wrap the tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate, including any existing rewards
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        vm.warp({newTimestamp: leafStartTime});
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 2});
        vm.startPrank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE * 2});

        _timeskip = bound(_timeskip, 1, WEEK - 1);
        _amount = bound(_amount, WEEK, MAX_BUFFER_CAP / 4);
        _initialAmount = bound(_amount, WEEK, MAX_BUFFER_CAP / 4);
        uint256 bufferCap = Math.max((_initialAmount + _amount) * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});
        vm.warp({newTimestamp: leafStartTime});

        deal({token: address(rootRewardToken), to: notifyAdmin, give: _initialAmount + _amount});
        vm.prank(notifyAdmin);
        rootRewardToken.approve({spender: address(rootGauge), value: _initialAmount + _amount});

        // inital deposit of partial amount
        vm.prank({msgSender: notifyAdmin, txOrigin: users.alice});
        rootGauge.notifyRewardWithoutClaim({_amount: _amount});

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        leafMailbox.processNextInboundMessage();

        vm.selectFork({forkId: rootId});
        vm.prank({msgSender: users.owner, txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: users.owner, _amount: _amount});
        rootGauge.notifyRewardWithoutClaim({_amount: _amount});

        assertEq(rootRewardToken.balanceOf(users.owner), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: _amount});
        vm.warp({newTimestamp: leafStartTime + _timeskip});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), _initialAmount + _amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;
        uint256 rewardRate = ((_amount / WEEK) * timeUntilNext + _amount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(leafStartTime)), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + timeUntilNext);
    }
}
