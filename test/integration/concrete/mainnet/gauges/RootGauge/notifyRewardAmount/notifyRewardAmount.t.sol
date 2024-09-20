// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGauge.t.sol";

contract NotifyRewardAmountIntegrationConcreteTest is RootGaugeTest {
    using stdStorage for StdStorage;

    uint256 public WEEKLY_DECAY;
    uint256 public TAIL_START_TIMESTAMP;

    function setUp() public override {
        super.setUp();

        WEEKLY_DECAY = rootGauge.WEEKLY_DECAY();
        TAIL_START_TIMESTAMP = rootGauge.TAIL_START_TIMESTAMP();

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

    modifier whenTailEmissionsHaveStarted() {
        /// @dev `weekly` on first week of tail emissions is approximately 5_950_167 tokens
        stdstore.target(address(minter)).sig("weekly()").checked_write(5_950_167 * TOKEN_1);
        /// @dev Overwrite `totalSupply` to be identical to VELO supply at fork timestamp
        stdstore.target(address(rootRewardToken)).sig("totalSupply()").checked_write(1_750_000_000 * TOKEN_1);
        stdstore.target(address(minter)).sig("activePeriod()").checked_write(rootGauge.TAIL_START_TIMESTAMP());
        _;
    }

    modifier whenTheAmountIsGreaterThanDefinedPercentageOfTailEmissions() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish()
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
        uint256 weeklyEmissions = (rootRewardToken.totalSupply() * IMinter(minter).tailEmissionRate()) / MAX_BPS;
        uint256 maxEmissionRate = rootGaugeFactory.emissionCaps(address(rootGauge));
        uint256 maxAmount = maxEmissionRate * weeklyEmissions / MAX_BPS;
        uint256 amount = maxAmount + TOKEN_1;
        uint256 bufferCap = Math.max(amount * 2, rootXVelo.minBufferCap() + 1);

        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: amount});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: amount});

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));
        uint256 oldMinterBalance = rootRewardToken.balanceOf(address(minter));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: maxAmount});
        rootGauge.notifyRewardAmount({_amount: amount});

        // Minter received excess emissions
        assertEq(rootRewardToken.balanceOf(address(minter)), oldMinterBalance + TOKEN_1);
        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
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

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish()
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
        uint256 weeklyEmissions = (rootRewardToken.totalSupply() * IMinter(minter).tailEmissionRate()) / MAX_BPS;
        uint256 maxEmissionRate = rootGaugeFactory.emissionCaps(address(rootGauge));
        uint256 maxAmount = maxEmissionRate * weeklyEmissions / MAX_BPS;
        uint256 amount = maxAmount + TOKEN_1;
        uint256 bufferCap = amount * 2;

        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 2});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE * 2});

        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: amount * 2});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: amount * 2});

        // inital deposit of partial amount
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        rootGauge.notifyRewardAmount({_amount: maxAmount});
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        skipTime(WEEK / 7 * 5);

        vm.selectFork({forkId: rootId});
        uint256 oldMinterBalance = rootRewardToken.balanceOf(address(minter));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: maxAmount});
        rootGauge.notifyRewardAmount({_amount: amount});

        // Minter received excess emissions
        assertEq(rootRewardToken.balanceOf(address(minter)), oldMinterBalance + TOKEN_1);
        assertEq(rootRewardToken.balanceOf(address(mockVoter)), amount - maxAmount);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: maxAmount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), maxAmount * 2);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = WEEK * 2 / 7;
        uint256 rewardRate = ((maxAmount / WEEK) * timeUntilNext + maxAmount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK / 7 * 2);
    }

    modifier whenTheAmountIsSmallerThanOrEqualToDefinedPercentageOfTailEmissions() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish_()
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
        uint256 amount = TOKEN_1 * 1_000;
        uint256 bufferCap = amount * 2;
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

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

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish_()
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

        uint256 amount = TOKEN_1 * 1_000;
        uint256 bufferCap = amount * 2;
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

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

    modifier whenTailEmissionsHaveNotStarted() {
        _;
    }

    modifier whenTheAmountIsGreaterThanDefinedPercentageOfWeeklyEmissions() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish__()
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
        uint256 amount = maxAmount + TOKEN_1;
        uint256 bufferCap = amount * 2;

        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: amount});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: amount});

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));
        uint256 oldMinterBalance = rootRewardToken.balanceOf(address(minter));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: maxAmount});
        rootGauge.notifyRewardAmount({_amount: amount});

        // Minter received excess emissions
        assertEq(rootRewardToken.balanceOf(address(minter)), oldMinterBalance + TOKEN_1);
        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
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

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish__()
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
        uint256 maxEmissionRate = rootGaugeFactory.emissionCaps(address(rootGauge));
        uint256 maxAmount = maxEmissionRate * weeklyEmissions / MAX_BPS;
        uint256 amount = maxAmount + TOKEN_1;
        uint256 bufferCap = amount * 2;

        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 2});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE * 2});

        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        deal({token: address(rootRewardToken), to: address(mockVoter), give: amount * 2});
        vm.prank(address(mockVoter));
        rootRewardToken.approve({spender: address(rootGauge), value: amount * 2});

        // inital deposit of partial amount
        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        rootGauge.notifyRewardAmount({_amount: maxAmount});
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        skipTime(WEEK / 7 * 5);

        vm.selectFork({forkId: rootId});
        uint256 oldMinterBalance = rootRewardToken.balanceOf(address(minter));

        vm.prank({msgSender: address(mockVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit IRootGauge.NotifyReward({_sender: address(mockVoter), _amount: maxAmount});
        rootGauge.notifyRewardAmount({_amount: amount});

        // Minter received excess emissions
        assertEq(rootRewardToken.balanceOf(address(minter)), oldMinterBalance + TOKEN_1);
        assertEq(rootRewardToken.balanceOf(address(mockVoter)), amount - maxAmount);
        assertEq(rootRewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafGauge));
        emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: maxAmount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), maxAmount * 2);

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        uint256 timeUntilNext = WEEK * 2 / 7;
        uint256 rewardRate = ((maxAmount / WEEK) * timeUntilNext + maxAmount) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK / 7 * 2);
    }

    modifier whenTheAmountIsSmallerThanOrEqualToDefinedPercentageOfWeeklyEmissions() {
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish___()
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
        uint256 amount = TOKEN_1 * 1_000;
        uint256 bufferCap = amount * 2;
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

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

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish___()
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

        uint256 amount = TOKEN_1 * 1_000;
        uint256 bufferCap = amount * 2;
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

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
