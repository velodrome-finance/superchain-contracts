// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract HLMessageBridgeTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootMessageModule.bridge(), address(rootMessageBridge));
        assertEq(rootMessageModule.mailbox(), address(rootMailbox));
        assertEq(address(rootMessageModule.securityModule()), address(rootIsm));
        assertEq(address(rootMessageModule).balance, 0);

        vm.selectFork({forkId: leafId});
        assertEq(leafMessageModule.bridge(), address(leafMessageBridge));
        assertEq(leafMessageModule.mailbox(), address(leafMailbox));
        assertEq(address(leafMessageModule.securityModule()), address(leafIsm));
        assertEq(address(leafMessageModule).balance, 0);
    }
}
