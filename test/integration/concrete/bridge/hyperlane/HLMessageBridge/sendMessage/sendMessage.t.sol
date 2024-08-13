// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLMessageBridge.t.sol";

contract SendMessageIntegrationConcreteTest is HLMessageBridgeTest {
    MockMessageReceiver mockReceiver;

    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});

        mockReceiver = new MockMessageReceiver();

        vm.selectFork({forkId: rootId});
    }

    function test_WhenTheCallerIsNotBridge() external {
        // It reverts with NotBridge
        vm.prank(users.charlie);
        vm.expectRevert(IHLMessageBridge.NotBridge.selector);
        rootMessageModule.sendMessage({
            _sender: users.charlie,
            _payload: abi.encode(users.charlie, abi.encode(1)),
            _chainid: leaf
        });
    }

    function test_WhenTheCallerIsBridge() external {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        bytes memory message = abi.encode(1000);
        vm.prank(address(rootMessageBridge));
        vm.expectEmit(address(rootMessageModule));
        emit IHLMessageBridge.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: 0,
            _message: string(abi.encode(address(mockReceiver), message))
        });
        rootMessageModule.sendMessage({_sender: address(mockReceiver), _payload: message, _chainid: leaf});

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(mockReceiver.amount(), 1000);
    }
}
