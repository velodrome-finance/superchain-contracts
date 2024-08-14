// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract TokenBridgeTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootTokenBridge.owner(), users.owner);
        assertEq(rootTokenBridge.xerc20(), address(rootXVelo));
        assertEq(rootTokenBridge.module(), address(rootTokenModule));
        assertEq(address(rootTokenBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        assertEq(leafTokenBridge.owner(), users.owner);
        assertEq(leafTokenBridge.xerc20(), address(leafXVelo));
        assertEq(leafTokenBridge.module(), address(leafTokenModule));
        assertEq(address(leafTokenBridge).balance, 0);
    }
}
