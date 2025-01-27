// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootEscrowTokenBridgeTest is BaseForkFixture {
    RootEscrowTokenBridge rootEscrowTokenBridge;

    function setUp() public virtual override {
        super.setUp();
        rootEscrowTokenBridge = RootEscrowTokenBridge(address(rootTokenBridge));
    }

    function test_InitialState() public view {
        assertEq(address(rootEscrowTokenBridge.lockbox()), address(rootLockbox));
        assertEq(address(rootEscrowTokenBridge.erc20()), address(rootRewardToken));
        assertEq(rootEscrowTokenBridge.owner(), users.owner);
        assertEq(rootEscrowTokenBridge.xerc20(), address(rootXVelo));
        assertEq(rootEscrowTokenBridge.mailbox(), address(rootMailbox));
        assertEq(rootEscrowTokenBridge.hook(), address(0));
        assertEq(rootEscrowTokenBridge.module(), address(rootMessageModule));
        assertEq(address(rootEscrowTokenBridge.securityModule()), address(0));
        assertEq(address(rootEscrowTokenBridge).balance, 0);
        assertEq(address(rootEscrowTokenBridge.escrow()), address(mockEscrow));

        uint256[] memory chainids = rootEscrowTokenBridge.chainids();
        assertEq(chainids.length, 0);
    }
}
