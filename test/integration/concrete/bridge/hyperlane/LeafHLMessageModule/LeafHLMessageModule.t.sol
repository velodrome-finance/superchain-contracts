// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract LeafHLMessageModuleTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: leafId});
        assertEq(leafMessageModule.owner(), users.owner);
        assertEq(leafMessageModule.bridge(), address(leafMessageBridge));
        assertEq(leafMessageModule.xerc20(), address(leafXVelo));
        assertEq(leafMessageModule.mailbox(), address(leafMailbox));
        assertEq(leafMessageModule.voter(), address(leafVoter));
        assertEq(address(leafMessageModule.securityModule()), address(leafIsm));
        assertEq(leafMessageModule.receivingNonce(), 0);
    }
}
