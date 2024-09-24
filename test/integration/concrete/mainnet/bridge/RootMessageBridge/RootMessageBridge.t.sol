// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootMessageBridgeTest is BaseForkFixture {
    function test_InitialState() public virtual {
        vm.selectFork({forkId: rootId});
        assertEq(rootMessageBridge.owner(), users.owner);
        assertEq(rootMessageBridge.xerc20(), address(rootXVelo));
        assertEq(rootMessageBridge.voter(), address(mockVoter));
        assertEq(rootMessageBridge.factoryRegistry(), address(mockFactoryRegistry));
        assertEq(rootMessageBridge.weth(), address(weth));
        uint256[] memory chainids = rootMessageBridge.chainids();
        assertEq(chainids.length, 0);
        address[] memory modules = rootMessageBridge.modules();
        assertEq(modules.length, 0);
    }
}
