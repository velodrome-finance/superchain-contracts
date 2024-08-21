// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract MessageBridgeTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootMessageBridge.module(), address(rootMessageModule));
        assertEq(rootMessageBridge.owner(), users.owner);
        assertEq(rootMessageBridge.voter(), address(mockVoter));
        assertEq(address(rootMessageBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        assertEq(leafMessageBridge.module(), address(leafMessageModule));
        assertEq(leafMessageBridge.owner(), users.owner);
        assertEq(leafMessageBridge.voter(), address(leafVoter));
        assertEq(address(leafMessageBridge).balance, 0);
    }
}