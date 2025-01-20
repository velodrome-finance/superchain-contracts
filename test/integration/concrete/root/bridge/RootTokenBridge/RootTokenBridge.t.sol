// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootTokenBridgeTest is BaseForkFixture {
    function test_InitialState() public {
        assertEq(address(rootTokenBridge.lockbox()), address(rootLockbox));
        assertEq(address(rootTokenBridge.erc20()), address(rootRewardToken));
        assertEq(rootTokenBridge.owner(), users.owner);
        assertEq(rootTokenBridge.xerc20(), address(rootXVelo));
        assertEq(rootTokenBridge.mailbox(), address(rootMailbox));
        assertEq(rootTokenBridge.hook(), address(0));
        assertEq(address(rootTokenBridge.securityModule()), address(0));
        assertEq(address(rootTokenBridge).balance, 0);

        uint256[] memory chainids = rootTokenBridge.chainids();
        assertEq(chainids.length, 0);
    }
}
