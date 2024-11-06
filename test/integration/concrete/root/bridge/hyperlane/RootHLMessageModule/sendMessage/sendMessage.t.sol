// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SendMessageIntegrationConcreteTest is RootHLMessageModuleTest {
    using GasLimits for uint256;

    uint256 public tokenId = 1;
    uint256 public constant ethAmount = TOKEN_1;
    uint256 public constant amount = TOKEN_1 * 1000;

    function test_WhenTheCallerIsNotBridge() external {
        // It reverts with {NotBridge}
        vm.prank(users.charlie);
        vm.expectRevert(IMessageSender.NotBridge.selector);
        rootMessageModule.sendMessage({
            _chainid: leaf,
            _message: abi.encodePacked(uint8(Commands.DEPOSIT), users.charlie, uint256(1))
        });
    }

    modifier whenTheCallerIsBridge() {
        _;
    }

    function test_WhenTheCommandIsDeposit() external whenTheCallerIsBridge {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload

        // Create Lock for Alice
        vm.startPrank(users.alice);
        deal(address(rootRewardToken), users.alice, amount);
        rootRewardToken.approve(address(mockEscrow), amount);
        tokenId = mockEscrow.createLock(amount, 4 * 365 * 86400);

        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});

        skipToNextEpoch(0); // warp to start of next epoch

        uint40 timestamp = uint40(block.timestamp);
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, timestamp);
        bytes memory expectedMessage =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, timestamp);
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

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
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        vm.selectFork({forkId: leafId});
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

    function test_WhenTheCommandIsNotify() external whenTheCallerIsBridge {
        // It burns the decoded amount of tokens
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        uint256 rootTimestamp = block.timestamp;
        vm.warp({newTimestamp: rootTimestamp});
        deal(address(rootXVelo), address(rootMessageModule), amount);
        setLimits({_rootBufferCap: amount * 2, _leafBufferCap: amount * 2});
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), amount);
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
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function test_WhenTheCommandIsNotifyWithoutClaim() external whenTheCallerIsBridge {
        // It burns the decoded amount of tokens
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        uint256 rootTimestamp = block.timestamp;
        vm.warp({newTimestamp: rootTimestamp});
        deal(address(rootXVelo), address(rootMessageModule), amount);
        setLimits({_rootBufferCap: amount * 2, _leafBufferCap: amount * 2});
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY_WITHOUT_CLAIM), address(leafGauge), amount);
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
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    modifier whenTheCommandIsGetIncentives() {
        // Create Lock for Alice
        vm.startPrank(users.alice);
        deal(address(rootRewardToken), users.alice, amount);
        rootRewardToken.approve(address(mockEscrow), amount);
        tokenId = mockEscrow.createLock(amount, 4 * 365 * 86400);
        _;
    }

    function test_WhenTimestampIsGreaterThanEpochVoteEnd()
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetIncentives
    {
        // It should revert with {SpecialVotingWindow}
        vm.warp({newTimestamp: VelodromeTimeLibrary.epochVoteEnd(block.timestamp) + 1});

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
        // Warp to start of epoch
        rootStartTime = VelodromeTimeLibrary.epochStart(block.timestamp) + 1;
        vm.warp({newTimestamp: rootStartTime});
        _;
    }

    function test_WhenTimestampIsSmallerThanOrEqualToEpochVoteStart()
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetIncentives
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd
    {
        // It should revert with {DistributeWindow}
        assertLe(block.timestamp, VelodromeTimeLibrary.epochVoteStart(block.timestamp));

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

    modifier whenTimestampIsGreaterThanEpochVoteStart() {
        // Warp to after distribute window
        rootStartTime = VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1;
        vm.warp({newTimestamp: rootStartTime});

        // Notify rewards contracts
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: rootStartTime});
        deal(address(token0), address(leafGauge), TOKEN_1);
        deal(address(token1), address(leafGauge), TOKEN_1);
        // Using WETH as Incentive token
        deal(address(weth), address(leafGauge), TOKEN_1);

        vm.startPrank(address(leafGauge));
        token0.approve(address(leafIVR), TOKEN_1);
        token1.approve(address(leafIVR), TOKEN_1);
        weth.approve(address(leafIVR), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token1), TOKEN_1);
        leafIVR.notifyRewardAmount(address(weth), TOKEN_1);

        // Deposit to vest rewards
        vm.startPrank(address(leafMessageModule));
        leafIVR._deposit({amount: amount, tokenId: tokenId, timestamp: block.timestamp});

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

    function test_WhenLastVoteIsInCurrentEpoch()
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetIncentives
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd
        whenTimestampIsGreaterThanEpochVoteStart
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

    function test_WhenLastVoteIsNotInCurrentEpoch()
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetIncentives
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd
        whenTimestampIsGreaterThanEpochVoteStart
    {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload

        // Skip to next epoch, after distribute window
        uint256 rootTimestamp = VelodromeTimeLibrary.epochNext(block.timestamp) + 1 hours + 1;
        vm.warp({newTimestamp: rootTimestamp});

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
        vm.warp({newTimestamp: rootTimestamp});
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafIVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: TOKEN_1});
        }
        leafMailbox.processNextInboundMessage();

        assertEq(leafIVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(token1), tokenId), block.timestamp);
        assertEq(leafIVR.lastEarn(address(weth), tokenId), block.timestamp);

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
        assertEq(weth.balanceOf(users.alice), TOKEN_1);
    }

    modifier whenTheCommandIsGetFees() {
        // Create Lock for Alice
        vm.startPrank(users.alice);
        deal(address(rootRewardToken), users.alice, amount);
        rootRewardToken.approve(address(mockEscrow), amount);
        tokenId = mockEscrow.createLock(amount, 4 * 365 * 86400);
        _;
    }

    function test_WhenTimestampIsGreaterThanEpochVoteEnd_() external whenTheCallerIsBridge whenTheCommandIsGetFees {
        // It should revert with {SpecialVotingWindow}
        vm.warp({newTimestamp: VelodromeTimeLibrary.epochVoteEnd(block.timestamp) + 1});

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
        // Warp to start of epoch
        rootStartTime = VelodromeTimeLibrary.epochStart(block.timestamp) + 1;
        vm.warp({newTimestamp: rootStartTime});
        _;
    }

    function test_WhenTimestampIsSmallerThanOrEqualToEpochVoteStart_()
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetFees
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd_
    {
        // It should revert with {DistributeWindow}
        assertLe(block.timestamp, VelodromeTimeLibrary.epochVoteStart(block.timestamp));

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

    modifier whenTimestampIsGreaterThanEpochVoteStart_() {
        // Warp to after distribute window
        rootStartTime = VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1;
        vm.warp({newTimestamp: rootStartTime});

        // Notify rewards contracts
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: rootStartTime});
        deal(address(token0), address(leafGauge), TOKEN_1);
        deal(address(token1), address(leafGauge), TOKEN_1);

        vm.startPrank(address(leafGauge));
        token0.approve(address(leafFVR), TOKEN_1);
        token1.approve(address(leafFVR), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token1), TOKEN_1);

        // Deposit to vest rewards
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({amount: amount, tokenId: tokenId, timestamp: block.timestamp});

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

    function test_WhenLastVoteIsInCurrentEpoch_()
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetFees
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd_
        whenTimestampIsGreaterThanEpochVoteStart_
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

    function test_WhenLastVoteIsNotInCurrentEpoch_()
        external
        whenTheCallerIsBridge
        whenTheCommandIsGetFees
        whenTimestampIsSmallerThanOrEqualToEpochVoteEnd_
        whenTimestampIsGreaterThanEpochVoteStart_
    {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload

        // Skip to next epoch, after distribute window
        uint256 rootTimestamp = VelodromeTimeLibrary.epochNext(block.timestamp) + 1 hours + 1;
        vm.warp({newTimestamp: rootTimestamp});

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
        vm.warp({newTimestamp: rootTimestamp});
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(address(leafFVR));
            emit IReward.ClaimRewards({_sender: users.alice, _reward: tokens[i], _amount: TOKEN_1});
        }
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.lastEarn(address(token0), tokenId), block.timestamp);
        assertEq(leafFVR.lastEarn(address(token1), tokenId), block.timestamp);

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
    }

    function test_WhenTheCommandIsCreateGauge() external whenTheCallerIsBridge {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        vm.selectFork({forkId: leafId});
        uint24 _poolParam = 1;
        leafPool = Pool(leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), fee: _poolParam}));

        vm.selectFork({forkId: rootId});
        bytes memory message = abi.encodePacked(
            uint8(Commands.CREATE_GAUGE),
            address(rootPoolFactory),
            address(rootVotingRewardsFactory),
            address(rootGaugeFactory),
            address(token0),
            address(token1),
            _poolParam
        );

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(message),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount,
                    _gasLimit: Commands.CREATE_GAUGE.gasLimit(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        leafGauge = LeafGauge(leafVoter.gauges(address(leafPool)));
        assertEq(leafGauge.stakingToken(), address(leafPool));
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));
    }

    function testGas_sendMessage() external whenTheCallerIsBridge {
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId);
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
        snapLastCall("RootHLMessageModule_sendMessage_deposit");
    }
}
