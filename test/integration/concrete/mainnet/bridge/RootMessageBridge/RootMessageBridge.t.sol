// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootMessageBridgeTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootMessageBridge.module(), address(rootMessageModule));
        assertEq(rootMessageBridge.owner(), users.owner);
        assertEq(rootMessageBridge.xerc20(), address(rootXVelo));
        assertEq(rootMessageBridge.voter(), address(mockVoter));
        assertEq(rootMessageBridge.gaugeFactory(), address(rootGaugeFactory));
        assertEq(address(rootMessageBridge).balance, 0);
    }
}
