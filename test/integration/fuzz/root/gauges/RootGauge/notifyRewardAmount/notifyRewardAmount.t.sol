// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGauge.t.sol";

contract NotifyRewardAmountIntegrationFuzzTest is RootGaugeTest {
    using stdStorage for StdStorage;

    uint256 public WEEKLY_DECAY;
    uint256 public TAIL_START_TIMESTAMP;

    function setUp() public override {
        super.setUp();

        WEEKLY_DECAY = rootGaugeFactory.WEEKLY_DECAY();
        TAIL_START_TIMESTAMP = rootGaugeFactory.TAIL_START_TIMESTAMP();

        // use users.alice as tx.origin
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});

        skipToNextEpoch(0); // warp to start of next epoch
        vm.selectFork({forkId: leafId});
        leafStartTime = block.timestamp;
        vm.selectFork({forkId: rootId});
        rootStartTime = block.timestamp;
    }

    function testFuzz_WhenTheCallerIsNotVoter(address _caller) external {
        // It should revert with {NotVoter}
        vm.assume(_caller != address(mockVoter));

        vm.prank(_caller);
        vm.expectRevert(IRootGauge.NotVoter.selector);
        rootGauge.notifyRewardAmount({_amount: 0});
    }

    modifier whenTheCallerIsVoter() {
        vm.prank(address(mockVoter));
        _;
    }

    modifier whenTailEmissionsHaveStarted() {
        /// @dev `weekly` on first week of tail emissions is approximately 5_950_167 tokens
        stdstore.target(address(minter)).sig("weekly()").checked_write(5_950_167 * TOKEN_1);
        /// @dev Overwrite `totalSupply` to be identical to VELO supply at fork timestamp
        uint256 totalSupply = IERC20(minter.velo()).totalSupply();
        stdstore.target(address(rootRewardToken)).sig("totalSupply()").checked_write(totalSupply);
        stdstore.target(address(minter)).sig("activePeriod()").checked_write(rootGaugeFactory.TAIL_START_TIMESTAMP());
        _;
    }

    modifier whenTheAmountIsGreaterThanDefinedPercentageOfTailEmissions() {
        _;
    }

    function testFuzz_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish(uint256 _amount)
        external
        whenTheCallerIsVoter
        whenTailEmissionsHaveStarted
        whenTheAmountIsGreaterThanDefinedPercentageOfTailEmissions
        syncForkTimestamps
    {
        // It should return excess emissions to minter
        // It should wrap the remaining tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 weeklyEmissions = (rootRewardToken.totalSupply() * minter.tailEmissionRate()) / MAX_BPS;
        uint256 maxEmissionRate = rootGaugeFactory.emissionCaps(address(rootGauge));
        uint256 maxAmount = maxEmissionRate * weeklyEmissions / MAX_BPS;
        _amount = bound(_amount, maxAmount, MAX_BUFFER_CAP / 2);
        uint256 excessEmissions = _amount - maxAmount;

        uint256 bufferCap = Math.max(_amount * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});
        vm.warp({newTimestamp: leafStartTime});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: _amount});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: _amount});

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));
        uint256 oldMinterBalance = rootRewardToken.balanceOf(address(minter));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: maxAmount});
        rootGauge.notifyRewardAmount({_amount: _amount});

        // Minter received excess emissions
        assertEq(rootRewardToken.balanceOf(address(minter)), oldMinterBalance + excessEmissions);
        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: maxAmount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), maxAmount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), maxAmount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), maxAmount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function testFuzz_WhenTheCurrentTimestampIsLessThanPeriodFinish(
        uint256 _initialAmount,
        uint256 _amount,
        uint256 _timeskip
    )
        external
        whenTheCallerIsVoter
        whenTailEmissionsHaveStarted
        whenTheAmountIsGreaterThanDefinedPercentageOfTailEmissions
        syncForkTimestamps
    {
        // It should return excess emissions to minter
        // It should wrap the remaining tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate, including any existing rewards
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 weeklyEmissions = (rootRewardToken.totalSupply() * minter.tailEmissionRate()) / MAX_BPS;
        uint256 maxAmount = rootGaugeFactory.emissionCaps(address(rootGauge)) * weeklyEmissions / MAX_BPS;
        _amount = bound(_amount, maxAmount, MAX_BUFFER_CAP / 4);
        _initialAmount = bound(_initialAmount, WEEK, maxAmount);
        _timeskip = bound(_timeskip, 1, WEEK - 1);
        uint256 excessEmissions = _amount - maxAmount;
        uint256 bufferCap = (_amount + _initialAmount) * 2;

        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 2});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE * 2});

        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});
        vm.warp({newTimestamp: leafStartTime});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: _initialAmount + _amount});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: _initialAmount + _amount});

        // inital deposit of partial amount
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        rootGauge.notifyRewardAmount({_amount: _initialAmount});
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        leafMailbox.processNextInboundMessage();

        skipTime(_timeskip);

        vm.selectFork({forkId: rootId});
        uint256 oldMinterBalance = rootRewardToken.balanceOf(address(minter));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: maxAmount});
        rootGauge.notifyRewardAmount({_amount: _amount});

        // Minter received excess emissions
        assertEq(rootRewardToken.balanceOf(address(minter)), oldMinterBalance + excessEmissions);
        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime + _timeskip});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: maxAmount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), _initialAmount + maxAmount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;
        uint256 rewardRate = ((_initialAmount / WEEK) * timeUntilNext + maxAmount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + timeUntilNext);
    }

    modifier whenTheAmountIsSmallerThanOrEqualToDefinedPercentageOfTailEmissions() {
        _;
    }

    function testFuzz_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish_(uint256 _amount)
        external
        whenTheCallerIsVoter
        whenTailEmissionsHaveStarted
        whenTheAmountIsSmallerThanOrEqualToDefinedPercentageOfTailEmissions
        syncForkTimestamps
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
        uint256 weeklyEmissions = (rootRewardToken.totalSupply() * minter.tailEmissionRate()) / MAX_BPS;
        uint256 maxAmount = rootGaugeFactory.emissionCaps(address(rootGauge)) * weeklyEmissions / MAX_BPS;
        _amount = bound(_amount, WEEK, maxAmount);
        uint256 bufferCap = Math.max(_amount * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});
        vm.warp({newTimestamp: leafStartTime});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: _amount});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: _amount});

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: _amount});
        rootGauge.notifyRewardAmount({_amount: _amount});

        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: _amount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), _amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), _amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), _amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function testFuzz_WhenTheCurrentTimestampIsLessThanPeriodFinish_(
        uint256 _initialAmount,
        uint256 _amount,
        uint256 _timeskip
    )
        external
        whenTheCallerIsVoter
        whenTailEmissionsHaveStarted
        whenTheAmountIsSmallerThanOrEqualToDefinedPercentageOfTailEmissions
        syncForkTimestamps
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

        uint256 weeklyEmissions = (rootRewardToken.totalSupply() * minter.tailEmissionRate()) / MAX_BPS;
        uint256 maxAmount = rootGaugeFactory.emissionCaps(address(rootGauge)) * weeklyEmissions / MAX_BPS;
        _initialAmount = bound(_amount, WEEK, maxAmount);
        _amount = bound(_amount, WEEK, maxAmount);
        _timeskip = bound(_timeskip, 1, WEEK - 1);

        uint256 bufferCap = Math.max((_initialAmount + _amount) * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});
        vm.warp({newTimestamp: leafStartTime});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: _initialAmount + _amount});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: _initialAmount + _amount});

        // inital deposit of partial _amount
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        rootGauge.notifyRewardAmount({_amount: _amount});
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        leafMailbox.processNextInboundMessage();

        skipTime(_timeskip);

        vm.selectFork({forkId: rootId});
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: _amount});
        rootGauge.notifyRewardAmount({_amount: _amount});

        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime + _timeskip});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: _amount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), _initialAmount + _amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;
        uint256 rewardRate = ((_amount / WEEK) * timeUntilNext + _amount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + timeUntilNext);
    }

    modifier whenTailEmissionsHaveNotStarted() {
        _;
    }

    modifier whenTheAmountIsGreaterThanDefinedPercentageOfWeeklyEmissions() {
        _;
    }

    function testFuzz_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish__(uint256 _amount)
        external
        whenTheCallerIsVoter
        whenTailEmissionsHaveNotStarted
        whenTheAmountIsGreaterThanDefinedPercentageOfWeeklyEmissions
        syncForkTimestamps
    {
        // It should return excess emissions to minter
        // It should wrap the remaining tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 weeklyEmissions = (minter.weekly() * MAX_BPS) / WEEKLY_DECAY;
        uint256 maxEmissionRate = rootGaugeFactory.emissionCaps(address(rootGauge));
        uint256 maxAmount = maxEmissionRate * weeklyEmissions / MAX_BPS;
        _amount = bound(_amount, maxAmount, MAX_BUFFER_CAP / 2);
        uint256 excessEmissions = _amount - maxAmount;
        uint256 bufferCap = _amount * 2;

        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});
        vm.warp({newTimestamp: leafStartTime});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: _amount});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: _amount});

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));
        uint256 oldMinterBalance = rootRewardToken.balanceOf(address(minter));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: maxAmount});
        rootGauge.notifyRewardAmount({_amount: _amount});

        // Minter received excess emissions
        assertEq(rootRewardToken.balanceOf(address(minter)), oldMinterBalance + excessEmissions);
        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: maxAmount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), maxAmount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), maxAmount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), maxAmount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function testFuzz_WhenTheCurrentTimestampIsLessThanPeriodFinish__(
        uint256 _initialAmount,
        uint256 _amount,
        uint256 _timeskip
    )
        external
        whenTheCallerIsVoter
        whenTailEmissionsHaveNotStarted
        whenTheAmountIsGreaterThanDefinedPercentageOfWeeklyEmissions
        syncForkTimestamps
    {
        // It should return excess emissions to minter
        // It should wrap the remaining tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate, including any existing rewards
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 weeklyEmissions = (minter.weekly() * MAX_BPS) / WEEKLY_DECAY;
        uint256 maxAmount = rootGaugeFactory.emissionCaps(address(rootGauge)) * weeklyEmissions / MAX_BPS;
        _amount = bound(_amount, maxAmount, MAX_BUFFER_CAP / 4);
        _initialAmount = bound(_initialAmount, WEEK, maxAmount);
        _timeskip = bound(_timeskip, 1, WEEK - 1);
        uint256 excessEmissions = _amount - maxAmount;
        uint256 bufferCap = (_amount + _initialAmount) * 2;

        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 2});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE * 2});

        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});
        vm.warp({newTimestamp: leafStartTime});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: _initialAmount + _amount});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: _initialAmount + _amount});

        // inital deposit of partial amount
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        rootGauge.notifyRewardAmount({_amount: _initialAmount});
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        leafMailbox.processNextInboundMessage();

        skipTime(_timeskip);

        vm.selectFork({forkId: rootId});
        uint256 oldMinterBalance = rootRewardToken.balanceOf(address(minter));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: maxAmount});
        rootGauge.notifyRewardAmount({_amount: _amount});

        // Minter received excess emissions
        assertEq(rootRewardToken.balanceOf(address(minter)), oldMinterBalance + excessEmissions);
        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime + _timeskip});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: maxAmount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), _initialAmount + maxAmount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;
        uint256 rewardRate = ((_initialAmount / WEEK) * timeUntilNext + maxAmount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + timeUntilNext);
    }

    modifier whenTheAmountIsSmallerThanOrEqualToDefinedPercentageOfWeeklyEmissions() {
        _;
    }

    function testFuzz_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish___(uint256 _amount)
        external
        whenTheCallerIsVoter
        whenTailEmissionsHaveNotStarted
        whenTheAmountIsSmallerThanOrEqualToDefinedPercentageOfWeeklyEmissions
        syncForkTimestamps
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
        uint256 weeklyEmissions = (minter.weekly() * MAX_BPS) / WEEKLY_DECAY;
        uint256 maxAmount = rootGaugeFactory.emissionCaps(address(rootGauge)) * weeklyEmissions / MAX_BPS;
        _amount = bound(_amount, WEEK, maxAmount);
        uint256 bufferCap = Math.max(_amount * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});
        vm.warp({newTimestamp: leafStartTime});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: _amount});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: _amount});

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: _amount});
        rootGauge.notifyRewardAmount({_amount: _amount});

        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: _amount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), _amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), _amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), _amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function testFuzz_WhenTheCurrentTimestampIsLessThanPeriodFinish___(
        uint256 _initialAmount,
        uint256 _amount,
        uint256 _timeskip
    )
        external
        whenTheCallerIsVoter
        whenTailEmissionsHaveNotStarted
        whenTheAmountIsSmallerThanOrEqualToDefinedPercentageOfWeeklyEmissions
        syncForkTimestamps
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

        uint256 weeklyEmissions = (minter.weekly() * MAX_BPS) / WEEKLY_DECAY;
        uint256 maxAmount = rootGaugeFactory.emissionCaps(address(rootGauge)) * weeklyEmissions / MAX_BPS;
        _initialAmount = bound(_amount, WEEK, maxAmount);
        _amount = bound(_amount, WEEK, maxAmount);
        _timeskip = bound(_timeskip, 1, WEEK - 1);

        uint256 bufferCap = Math.max((_initialAmount + _amount) * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});
        vm.warp({newTimestamp: leafStartTime});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: _initialAmount + _amount});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: _initialAmount + _amount});

        // inital deposit of partial amount
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        rootGauge.notifyRewardAmount({_amount: _initialAmount});
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        leafMailbox.processNextInboundMessage();

        skipTime(_timeskip);

        vm.selectFork({forkId: rootId});
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: _amount});
        rootGauge.notifyRewardAmount({_amount: _amount});

        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime + _timeskip});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: _amount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), _initialAmount + _amount);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;
        uint256 rewardRate = ((_initialAmount / WEEK) * timeUntilNext + _amount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + timeUntilNext);
    }
}
