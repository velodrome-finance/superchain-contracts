// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../MessageBridge.t.sol";

contract SendMessageIntegrationConcreteTest is MessageBridgeTest {
    MockMessageReceiver mockReceiver;

    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});

        mockReceiver = new MockMessageReceiver();

        vm.selectFork({forkId: rootId});
    }

    function test_WhenTheCallerIsAnyone() external {
        // It dispatches the message to the message module
        vm.prank(address(mockReceiver));
        rootMessageBridge.sendMessage({_payload: abi.encode(1000), _chainid: leaf});

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(mockReceiver.amount(), 1000);
    }
}
