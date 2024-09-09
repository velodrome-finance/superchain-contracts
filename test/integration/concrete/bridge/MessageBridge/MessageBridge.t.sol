// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract MessageBridgeTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: leafId});
        assertEq(leafMessageBridge.module(), address(leafMessageModule));
        assertEq(leafMessageBridge.owner(), users.owner);
        assertEq(leafMessageBridge.xerc20(), address(leafXVelo));
        assertEq(leafMessageBridge.voter(), address(leafVoter));
        assertEq(leafMessageBridge.poolFactory(), address(leafPoolFactory));
        assertEq(address(leafMessageBridge).balance, 0);
    }
}
