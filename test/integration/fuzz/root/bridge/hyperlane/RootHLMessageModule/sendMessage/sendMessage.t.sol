// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SendMessageIntegrationFuzzTest is RootHLMessageModuleTest {
    using stdStorage for StdStorage;
    using GasLimits for uint256;

    uint256 public tokenId = 1;
    uint256 public amount = TOKEN_1 * 1000;
    uint256 public lockAmount = TOKEN_1 * 1000;
    uint256 public constant ethAmount = TOKEN_1;
    uint256 public constant MAX_TIME = 4 * 365 * DAY;

    function setUp() public override {
        super.setUp();

        skipToNextEpoch(0); // warp to start of next epoch
    }

    function testFuzz_WhenTheCallerIsNotBridge(address _caller) external {
        // It reverts with {NotBridge}
        vm.assume(_caller != address(rootMessageBridge));
        vm.prank(_caller);
        vm.expectRevert(IMessageSender.NotBridge.selector);
        rootMessageModule.sendMessage({_chainid: leaf, _message: abi.encodePacked(users.charlie, uint256(1))});
    }

    modifier whenTheCallerIsBridge() {
        _;
    }

    function testFuzz_WhenTheCommandIsDeposit(address _caller, uint256 _amount, uint256 _timestamp)
        external
        whenTheCallerIsBridge
    {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        amount = bound(_amount, 1, MAX_TOKENS);
        _timestamp = bound(
            _timestamp,
            VelodromeTimeLibrary.epochStart(block.timestamp),
            VelodromeTimeLibrary.epochVoteEnd(block.timestamp)
        );

        // Create Lock for Alice & Timeskip
        vm.startPrank(users.alice);
        deal(address(rootRewardToken), users.alice, amount);
        rootRewardToken.approve(address(mockEscrow), amount);
        tokenId = mockEscrow.createLock(amount, MAX_TIME);
        vm.stopPrank();

        vm.warp(_timestamp);

        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint40(_timestamp));
        bytes memory expectedMessage =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint40(_timestamp));
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: _caller});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(expectedMessage),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount,
                    _gasLimit: Commands.DEPOSIT.gasLimit(),
                    _refundAddress: _caller,
                    _customMetadata: ""
                })
            )
        });
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        vm.selectFork({forkId: leafId});
        vm.warp(_timestamp);
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        (uint256 checkpointTs, uint256 checkpointAmount) =
            leafFVR.checkpoints(tokenId, leafFVR.numCheckpoints(tokenId) - 1);
        assertEq(checkpointTs, _timestamp);
        assertEq(checkpointAmount, amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
        (checkpointTs, checkpointAmount) = leafIVR.checkpoints(tokenId, leafFVR.numCheckpoints(tokenId) - 1);
        assertEq(checkpointTs, _timestamp);
        assertEq(checkpointAmount, amount);
    }

    function testFuzz_WhenTheCommandIsNotify(uint256 _amount) external whenTheCallerIsBridge {
        // It burns the decoded amount of tokens
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        _amount = bound(_amount, TOKEN_1, MAX_BUFFER_CAP / 2);

        uint256 rootTimestamp = block.timestamp;
        vm.warp({newTimestamp: rootTimestamp});
        deal(address(rootXVelo), address(rootMessageModule), _amount);
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
        uint256 bufferCap = Math.max(_amount * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), _amount);
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(message),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount,
                    _gasLimit: Commands.NOTIFY.gasLimit(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        assertEq(rootXVelo.balanceOf(address(rootMessageModule)), 0);

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: rootTimestamp});
        leafMailbox.processNextInboundMessage();

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), _amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), _amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function testFuzz_WhenTheCommandIsNotifyWithoutClaim(uint256 _amount) external whenTheCallerIsBridge {
        // It burns the decoded amount of tokens
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        _amount = bound(_amount, TOKEN_1, MAX_BUFFER_CAP / 2);

        uint256 rootTimestamp = block.timestamp;
        vm.warp({newTimestamp: rootTimestamp});
        deal(address(rootXVelo), address(rootMessageModule), _amount);
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
        uint256 bufferCap = Math.max(_amount * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY_WITHOUT_CLAIM), address(leafGauge), _amount);
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(message),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount,
                    _gasLimit: Commands.NOTIFY_WITHOUT_CLAIM.gasLimit(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        assertEq(rootXVelo.balanceOf(address(rootMessageModule)), 0);

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: rootTimestamp});
        leafMailbox.processNextInboundMessage();

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), _amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), _amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    modifier whenTheCommandIsGetIncentives(uint256 _amount) {
        amount = bound(_amount, 1, TOKEN_1 * 1_000_000);
        // Warp to start of epoch
        rootStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: rootStartTime});

        // Create Lock for Alice
        vm.startPrank(users.alice);
        deal(address(rootRewardToken), users.alice, lockAmount);
        rootRewardToken.approve(address(mockEscrow), lockAmount);
        tokenId = mockEscrow.createLock(lockAmount, MAX_TIME);
        _;
    }

    function testFuzz_WhenTimestampIsGreaterThanEpochVoteEnd(uint256 _amount, uint256 _timestamp)
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetIncentives(_amount)
    {
        // It should revert with {SpecialVotingWindow}

        // Warp to start of epoch, before voting starts
        _timestamp = bound(
            _timestamp,
            VelodromeTimeLibrary.epochVoteEnd(block.timestamp) + 2,
            VelodromeTimeLibrary.epochNext(block.timestamp) - 1
        );
        vm.warp({newTimestamp: _timestamp});

        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_INCENTIVES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
        vm.expectRevert(IRootHLMessageModule.SpecialVotingWindow.selector);
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }

    modifier whenTimestampIsSmallerThanOrEqualToEpochVoteEnd() {
        _;
    }

    function testFuzz_WhenTimestampIsSmallerThanOrEqualToEpochVoteStart(uint256 _amount, uint256 _timestamp)
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetIncentives(_amount)
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd
    {
        // It should revert with {DistributeWindow}

        // Warp to start of epoch, before voting starts
        _timestamp = bound(
            _timestamp,
            VelodromeTimeLibrary.epochStart(block.timestamp),
            VelodromeTimeLibrary.epochVoteStart(block.timestamp)
        );
        vm.warp({newTimestamp: _timestamp});

        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_INCENTIVES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
        vm.expectRevert(IRootHLMessageModule.DistributeWindow.selector);
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }

    modifier whenTimestampIsGreaterThanEpochVoteStart(uint256 _timestamp) {
        // Warp to after distribute window & before blackout window
        rootStartTime = bound(
            _timestamp,
            VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1,
            VelodromeTimeLibrary.epochVoteEnd(block.timestamp)
        );

        // Notify rewards contracts
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: rootStartTime});
        deal(address(token0), address(leafGauge), amount);
        deal(address(token1), address(leafGauge), amount);
        // Using WETH as Incentive token
        deal(address(weth), address(leafGauge), amount);

        vm.startPrank(address(leafGauge));
        token0.approve(address(leafIVR), amount);
        token1.approve(address(leafIVR), amount);
        weth.approve(address(leafIVR), amount);
        leafIVR.notifyRewardAmount(address(token0), amount);
        leafIVR.notifyRewardAmount(address(token1), amount);
        leafIVR.notifyRewardAmount(address(weth), amount);

        // Deposit to vest rewards
        vm.startPrank(address(leafMessageModule));
        leafIVR._deposit({amount: lockAmount, tokenId: tokenId, timestamp: block.timestamp});

        vm.selectFork({forkId: rootId});
        vm.warp({newTimestamp: rootStartTime});
        address[] memory pools = new address[](1);
        pools[0] = address(rootPool);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 100;
        vm.startPrank(users.alice);
        mockVoter.vote(tokenId, pools, weights); // Vote to update `lastVoted`
        _;
    }

    function testFuzz_WhenLastVoteIsInCurrentEpoch(uint256 _timestamp)
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetIncentives(TOKEN_1)
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd
        whenTimestampIsGreaterThanEpochVoteStart(_timestamp)
    {
        // It should revert with {AlreadyVotedOrDeposited}
        assertGe(mockVoter.lastVoted(tokenId), VelodromeTimeLibrary.epochStart(block.timestamp));

        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_INCENTIVES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
        vm.expectRevert(IRootHLMessageModule.AlreadyVotedOrDeposited.selector);
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenLastVoteIsNotInCurrentEpoch(uint256 _amount, uint256 _timestamp)
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetIncentives(_amount)
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd
        whenTimestampIsGreaterThanEpochVoteStart(0)
    {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload

        // Skip to next epoch, after distribute window & before blackout window
        uint256 epochNext = VelodromeTimeLibrary.epochNext(block.timestamp) + 1 hours + 1;
        _timestamp = bound(_timestamp, epochNext, VelodromeTimeLibrary.epochVoteEnd(epochNext));
        vm.warp({newTimestamp: _timestamp});

        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_INCENTIVES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(message),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount,
                    _gasLimit: Commands.GET_INCENTIVES.gasLimit(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: _timestamp});
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafIVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: amount});
        }
        leafMailbox.processNextInboundMessage();

        assertEq(leafIVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(weth), tokenId), block.timestamp);

        assertEq(token0.balanceOf(users.alice), amount);
        assertEq(token1.balanceOf(users.alice), amount);
        assertEq(weth.balanceOf(users.alice), amount);
    }

    modifier whenTheCommandIsGetFees(uint256 _amount) {
        amount = bound(_amount, 1, TOKEN_1 * 1_000_000);
        // Warp to start of epoch
        rootStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: rootStartTime});

        // Create Lock for Alice
        vm.startPrank(users.alice);
        deal(address(rootRewardToken), users.alice, lockAmount);
        rootRewardToken.approve(address(mockEscrow), lockAmount);
        tokenId = mockEscrow.createLock(lockAmount, MAX_TIME);
        _;
    }

    function testFuzz_WhenTimestampIsGreaterThanEpochVoteEnd_(uint256 _amount, uint256 _timestamp)
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetIncentives(_amount)
    {
        // It should revert with {SpecialVotingWindow}

        // Warp to start of epoch, before voting starts
        _timestamp = bound(
            _timestamp,
            VelodromeTimeLibrary.epochVoteEnd(block.timestamp) + 2,
            VelodromeTimeLibrary.epochNext(block.timestamp) - 1
        );
        vm.warp({newTimestamp: _timestamp});

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_FEES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
        vm.expectRevert(IRootHLMessageModule.SpecialVotingWindow.selector);
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }

    modifier whenTimestampIsSmallerThanOrEqualToEpochVoteEnd_() {
        _;
    }

    function testFuzz_WhenTimestampIsSmallerThanOrEqualToEpochVoteStart_(uint256 _amount, uint256 _timestamp)
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetIncentives(_amount)
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd_
    {
        // It should revert with {DistributeWindow}

        // Warp to start of epoch, before voting starts
        _timestamp = bound(
            _timestamp,
            VelodromeTimeLibrary.epochStart(block.timestamp),
            VelodromeTimeLibrary.epochVoteStart(block.timestamp)
        );
        vm.warp({newTimestamp: _timestamp});

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_FEES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
        vm.expectRevert(IRootHLMessageModule.DistributeWindow.selector);
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }

    modifier whenTimestampIsGreaterThanEpochVoteStart_(uint256 _timestamp) {
        // Warp to after distribute window & before blackout window
        rootStartTime = bound(
            _timestamp,
            VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1,
            VelodromeTimeLibrary.epochVoteEnd(block.timestamp)
        );

        // Notify rewards contracts
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: rootStartTime});
        deal(address(token0), address(leafGauge), amount);
        deal(address(token1), address(leafGauge), amount);

        vm.startPrank(address(leafGauge));
        token0.approve(address(leafFVR), amount);
        token1.approve(address(leafFVR), amount);
        leafFVR.notifyRewardAmount(address(token0), amount);
        leafFVR.notifyRewardAmount(address(token1), amount);

        // Deposit to vest rewards
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({amount: lockAmount, tokenId: tokenId, timestamp: block.timestamp});

        vm.selectFork({forkId: rootId});
        vm.warp({newTimestamp: rootStartTime});
        address[] memory pools = new address[](1);
        pools[0] = address(rootPool);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 100;
        vm.startPrank(users.alice);
        mockVoter.vote(tokenId, pools, weights); // Vote to update `lastVoted`
        _;
    }

    function testFuzz_WhenLastVoteIsInCurrentEpoch_(uint256 _timestamp)
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetFees(TOKEN_1)
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd_
        whenTimestampIsGreaterThanEpochVoteStart_(_timestamp)
    {
        // It should revert with {AlreadyVotedOrDeposited}
        assertGe(mockVoter.lastVoted(tokenId), VelodromeTimeLibrary.epochStart(block.timestamp));

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_FEES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
        vm.expectRevert(IRootHLMessageModule.AlreadyVotedOrDeposited.selector);
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenLastVoteIsNotInCurrentEpoch_(uint256 _amount, uint256 _timestamp)
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetFees(_amount)
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd_
        whenTimestampIsGreaterThanEpochVoteStart_(_timestamp)
    {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload

        // Skip to next epoch, after distribute window & before blackout window
        uint256 epochNext = VelodromeTimeLibrary.epochNext(block.timestamp) + 1 hours + 1;
        _timestamp = bound(_timestamp, epochNext, VelodromeTimeLibrary.epochVoteEnd(epochNext));
        vm.warp({newTimestamp: _timestamp});

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_FEES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(message),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount,
                    _gasLimit: Commands.GET_FEES.gasLimit(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: _timestamp});
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafFVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: amount});
        }
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(token1), tokenId), block.timestamp);

        assertEq(token0.balanceOf(users.alice), amount);
        assertEq(token1.balanceOf(users.alice), amount);
    }

    function testFuzz_WhenTheCommandIsCreateGauge() external whenTheCallerIsBridge {}
}
