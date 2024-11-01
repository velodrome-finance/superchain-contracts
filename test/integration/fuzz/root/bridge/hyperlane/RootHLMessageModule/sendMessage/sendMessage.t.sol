// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SendMessageIntegrationFuzzTest is RootHLMessageModuleTest {
    using stdStorage for StdStorage;
    using GasLimits for uint256;

    uint256 public timestamp;
    uint256 public tokenId = 1;
    uint256 public amount = TOKEN_1 * 1000;
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

    modifier whenTheCommandIsDeposit(uint256 _amount) {
        amount = bound(_amount, 1, MAX_TOKENS);
        // Create Lock for Alice
        vm.startPrank(users.alice);
        deal(address(rootRewardToken), users.alice, amount);
        rootRewardToken.approve(address(mockEscrow), amount);
        tokenId = mockEscrow.createLock(amount, MAX_TIME);
        vm.stopPrank();
        _;
    }

    function testFuzz_WhenTimestampIsSmallerThanOrEqualToEpochVoteEnd(
        address _caller,
        uint256 _amount,
        uint256 _timestamp
    ) external whenTheCallerIsBridge whenTheCommandIsDeposit(_amount) {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        _timestamp = bound(
            _timestamp,
            VelodromeTimeLibrary.epochStart(block.timestamp),
            VelodromeTimeLibrary.epochVoteEnd(block.timestamp)
        );
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

    modifier whenTimestampIsGreaterThanEpochVoteEnd(uint256 _timestamp) {
        /// @dev Skip somewhere after epoch voting ends
        timestamp = bound(
            _timestamp,
            VelodromeTimeLibrary.epochVoteEnd(block.timestamp) + 1,
            VelodromeTimeLibrary.epochNext(block.timestamp) - 1
        );
        vm.warp(timestamp);
        _;
    }

    function testFuzz_WhenTxOriginIsNotApprovedOrOwnerOfTokenId(address _caller, uint256 _amount, uint256 _timestamp)
        external
        whenTheCallerIsBridge
        whenTheCommandIsDeposit(_amount)
        whenTimestampIsGreaterThanEpochVoteEnd(_timestamp)
    {
        // It reverts with {NotApprovedOrOwner}
        vm.assume(_caller != users.alice);

        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint40(_timestamp));
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: _caller});
        assertGt(block.timestamp, VelodromeTimeLibrary.epochVoteEnd(block.timestamp));
        vm.expectRevert(IRootHLMessageModule.NotApprovedOrOwner.selector);
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenTxOriginIsApprovedOrOwnerOfTokenId(address _caller, uint256 _amount, uint256 _timestamp)
        external
        whenTheCallerIsBridge
        whenTheCommandIsDeposit(_amount)
        whenTimestampIsGreaterThanEpochVoteEnd(_timestamp)
    {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        vm.assume(_caller != address(0));
        if (_caller != users.alice) {
            vm.prank(users.alice);
            mockEscrow.approve({to: _caller, tokenId: tokenId});
        }

        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint40(timestamp));
        bytes memory expectedMessage =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint40(timestamp));
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
        vm.warp(timestamp);
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        (uint256 checkpointTs, uint256 checkpointAmount) =
            leafFVR.checkpoints(tokenId, leafFVR.numCheckpoints(tokenId) - 1);
        assertEq(checkpointTs, timestamp);
        assertEq(checkpointAmount, amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
        (checkpointTs, checkpointAmount) = leafIVR.checkpoints(tokenId, leafFVR.numCheckpoints(tokenId) - 1);
        assertEq(checkpointTs, timestamp);
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
        // Warp to start of epoch, after distribute window
        rootStartTime = VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1;
        vm.warp({newTimestamp: rootStartTime});

        // Create Lock for Alice
        vm.startPrank(users.alice);
        uint256 lockAmount = TOKEN_1 * 1000;
        deal(address(rootRewardToken), users.alice, lockAmount);
        rootRewardToken.approve(address(mockEscrow), lockAmount);
        tokenId = mockEscrow.createLock(lockAmount, MAX_TIME);

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
    {
        // It should revert with {AlreadyVotedOrDeposited}
        _timestamp = bound(_timestamp, block.timestamp, VelodromeTimeLibrary.epochNext(block.timestamp) - 1);
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
    {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        uint256 epochNext = VelodromeTimeLibrary.epochNext(block.timestamp);
        _timestamp = bound(_timestamp, epochNext, epochNext + MAX_TIME);
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
        // Warp to start of epoch, after distribute window
        rootStartTime = VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1;
        vm.warp({newTimestamp: rootStartTime});

        // Create Lock for Alice
        vm.startPrank(users.alice);
        uint256 lockAmount = TOKEN_1 * 1000;
        deal(address(rootRewardToken), users.alice, lockAmount);
        rootRewardToken.approve(address(mockEscrow), lockAmount);
        tokenId = mockEscrow.createLock(lockAmount, MAX_TIME);

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
    {
        // It should revert with {AlreadyVotedOrDeposited}
        _timestamp = bound(_timestamp, block.timestamp, VelodromeTimeLibrary.epochNext(block.timestamp) - 1);
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
    {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        uint256 epochNext = VelodromeTimeLibrary.epochNext(block.timestamp);
        _timestamp = bound(_timestamp, epochNext, epochNext + MAX_TIME);
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
