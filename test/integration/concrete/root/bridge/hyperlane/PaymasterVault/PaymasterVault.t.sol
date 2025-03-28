// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract PaymasterVaultTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootModuleVault.owner(), users.owner);
        assertEq(address(rootModuleVault).balance, MESSAGE_FEE * 1_000);
    }
}
