// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SendMessageIntegrationConcreteTest is RootHLMessageModuleTest {
    using stdStorage for StdStorage;

    function test_WhenTheCallerIsNotBridge() external {
        // It reverts with NotBridge
        vm.prank(users.charlie);
        vm.expectRevert(IMessageSender.NotBridge.selector);
        rootMessageModule.sendMessage({_chainid: leaf, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheCallerIsBridge() {
        vm.startPrank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        _;
    }

    function test_WhenTheCommandIsDeposit() external whenTheCallerIsBridge {
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
        uint256 ethAmount = TOKEN_1;
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));
        bytes memory expectedMessage =
            abi.encode(Commands.DEPOSIT, abi.encode(1_000, abi.encode(address(leafGauge), payload)));
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(expectedMessage)
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

        uint256 ethAmount = TOKEN_1;
        bytes memory payload = abi.encode(
            address(rootVotingRewardsFactory), address(rootGaugeFactory), address(token0), address(token1), _poolParam
        );
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, abi.encode(address(rootPoolFactory), payload));

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(message)
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
}
