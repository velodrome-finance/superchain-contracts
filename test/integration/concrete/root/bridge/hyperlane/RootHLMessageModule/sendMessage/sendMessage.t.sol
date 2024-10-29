// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SendMessageIntegrationConcreteTest is RootHLMessageModuleTest {
    using stdStorage for StdStorage;
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
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        _;
    }

    modifier whenTheCommandIsDeposit() {
        // Create Lock for Alice
        vm.stopPrank();
        vm.startPrank(users.alice);
        deal(address(rootRewardToken), users.alice, amount);
        rootRewardToken.approve(address(mockEscrow), amount);
        tokenId = mockEscrow.createLock(amount, 4 * 365 * 86400);

        stdstore.target(address(rootMessageModule)).sig(rootMessageModule.sendingNonce.selector).with_key(leaf)
            .checked_write(1_000);

        vm.selectFork({forkId: leafId});
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        vm.selectFork({forkId: rootId});
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});

        skipToNextEpoch(0); // warp to start of next epoch
        _;
    }

    function test_WhenTimestampIsSmallerThanOrEqualToEpochVoteEnd()
        external
        whenTheCallerIsBridge
        whenTheCommandIsDeposit
    {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It should update sendingNonce
        // It calls receiveMessage on the recipient contract of the same address with the payload
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId);
        bytes memory expectedMessage =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint256(1_000));
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

        assertEq(rootMessageModule.sendingNonce(leaf), 1_001);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
        assertEq(leafMessageModule.receivingNonce(), 1_001);
    }

    modifier whenTimestampIsGreaterThanEpochVoteEnd() {
        /// @dev Skip 30 minutes after epoch voting ends
        vm.warp(VelodromeTimeLibrary.epochVoteEnd(block.timestamp) + 30 minutes);
        _;
    }

    function test_WhenTxOriginIsNotApprovedOrOwnerOfTokenId()
        external
        whenTheCallerIsBridge
        whenTheCommandIsDeposit
        whenTimestampIsGreaterThanEpochVoteEnd
    {
        // It reverts with {NotApprovedOrOwner}
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId);
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        vm.stopPrank();
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.charlie});
        vm.expectRevert(IRootHLMessageModule.NotApprovedOrOwner.selector);
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
    }

    function test_WhenTxOriginIsApprovedOrOwnerOfTokenId()
        external
        whenTheCallerIsBridge
        whenTheCommandIsDeposit
        whenTimestampIsGreaterThanEpochVoteEnd
    {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It should update sendingNonce
        // It calls receiveMessage on the recipient contract of the same address with the payload
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId);
        bytes memory expectedMessage =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint256(1_000));
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

        assertEq(rootMessageModule.sendingNonce(leaf), 1_001);

        vm.selectFork({forkId: leafId});
        /// @dev Skip 30 minutes after epoch voting ends
        vm.warp(VelodromeTimeLibrary.epochVoteEnd(block.timestamp) + 30 minutes);
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
        assertEq(leafMessageModule.receivingNonce(), 1_001);
    }

    function test_WhenTheCommandIsNotify() external whenTheCallerIsBridge {
        // It burns the decoded amount of tokens
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It should update sendingNonce
        // It calls receiveMessage on the recipient contract of the same address with the payload
        vm.selectFork({forkId: rootId});
        stdstore.target(address(rootMessageModule)).sig(rootMessageModule.sendingNonce.selector).with_key(leaf)
            .checked_write(1_000);
        vm.selectFork({forkId: leafId});
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        vm.selectFork({forkId: rootId});

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

        assertEq(rootMessageModule.sendingNonce(leaf), 1_000);
        assertEq(rootXVelo.balanceOf(address(rootMessageModule)), 0);

        vm.selectFork({forkId: leafId});
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
        // It should update sendingNonce
        // It calls receiveMessage on the recipient contract of the same address with the payload
        vm.selectFork({forkId: rootId});
        stdstore.target(address(rootMessageModule)).sig(rootMessageModule.sendingNonce.selector).with_key(leaf)
            .checked_write(1_000);
        vm.selectFork({forkId: leafId});
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        vm.selectFork({forkId: rootId});

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

        assertEq(rootMessageModule.sendingNonce(leaf), 1_000);
        assertEq(rootXVelo.balanceOf(address(rootMessageModule)), 0);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function test_WhenTheCommandIsCreateGauge() external whenTheCallerIsBridge {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It shouldn't update sendingNonce
        // It calls receiveMessage on the recipient contract of the same address with the payload
        vm.selectFork({forkId: rootId});
        stdstore.target(address(rootMessageModule)).sig(rootMessageModule.sendingNonce.selector).with_key(leaf)
            .checked_write(1_000);
        vm.selectFork({forkId: leafId});
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

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

        assertEq(rootMessageModule.sendingNonce(leaf), 1_000);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        leafGauge = LeafGauge(leafVoter.gauges(address(leafPool)));
        assertEq(leafGauge.stakingToken(), address(leafPool));
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    function testGas_sendMessage()
        external
        whenTheCallerIsBridge
        whenTheCommandIsDeposit
        whenTimestampIsGreaterThanEpochVoteEnd
    {
        vm.selectFork({forkId: rootId});
        stdstore.target(address(rootMessageModule)).sig(rootMessageModule.sendingNonce.selector).with_key(leaf)
            .checked_write(1_000);
        vm.selectFork({forkId: leafId});
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        vm.selectFork({forkId: rootId});
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId);
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});
        snapLastCall("RootHLMessageModule_sendMessage_deposit");
    }
}
