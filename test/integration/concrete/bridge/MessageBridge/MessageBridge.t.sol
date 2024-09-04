// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract MessageBridgeTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootMessageBridge.module(), address(rootMessageModule));
        assertEq(rootMessageBridge.owner(), users.owner);
        assertEq(rootMessageBridge.xerc20(), address(rootXVelo));
        assertEq(rootMessageBridge.voter(), address(mockVoter));
        assertEq(rootMessageBridge.poolFactory(), address(0));
        assertEq(rootMessageBridge.gaugeFactory(), address(rootGaugeFactory));
        assertEq(address(rootMessageBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        assertEq(leafMessageBridge.module(), address(leafMessageModule));
        assertEq(leafMessageBridge.owner(), users.owner);
        assertEq(leafMessageBridge.xerc20(), address(leafXVelo));
        assertEq(leafMessageBridge.voter(), address(leafVoter));
        assertEq(rootMessageBridge.poolFactory(), address(leafPoolFactory));
        assertEq(rootMessageBridge.gaugeFactory(), address(0));
        assertEq(address(leafMessageBridge).balance, 0);
    }
}
