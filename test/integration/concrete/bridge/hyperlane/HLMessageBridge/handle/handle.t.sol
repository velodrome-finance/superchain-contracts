// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLMessageBridge.t.sol";

contract HandleIntegrationConcreteTest is HLMessageBridgeTest {
    MockMessageReceiver mockReceiver;

    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});

        mockReceiver = new MockMessageReceiver();
    }

    function test_WhenCallerIsNotMailbox() external {
        // It reverts with NotMailbox
        vm.prank(users.charlie);
        vm.expectRevert(IHLMessageBridge.NotMailbox.selector);
        leafMessageModule.handle({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(users.charlie),
            _message: abi.encode(users.charlie, abi.encode(1))
        });
    }

    function test_WhenCallerIsMailbox() external {
        // It calls receivedMessage on the recipient contract of the same address with the payload
        // It emits the {ReceivedMessage} event
        bytes memory message = abi.encode(address(mockReceiver), abi.encode(1000));

        vm.prank(address(leafMailbox));
        emit IHLMessageBridge.ReceivedMessage({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(address(leafMessageModule)),
            _value: 0,
            _message: string(message)
        });
        leafMessageModule.handle({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(address(leafMessageModule)),
            _message: message
        });

        assertEq(mockReceiver.amount(), 1000);
    }
}
