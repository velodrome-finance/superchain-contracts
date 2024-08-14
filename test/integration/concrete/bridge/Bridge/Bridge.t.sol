// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract BridgeTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootBridge.owner(), users.owner);
        assertEq(rootBridge.xerc20(), address(rootXVelo));
        assertEq(rootBridge.module(), address(rootModule));
        assertEq(address(rootBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        assertEq(leafBridge.owner(), users.owner);
        assertEq(leafBridge.xerc20(), address(leafXVelo));
        assertEq(leafBridge.module(), address(leafModule));
        assertEq(address(leafBridge).balance, 0);
    }
}
