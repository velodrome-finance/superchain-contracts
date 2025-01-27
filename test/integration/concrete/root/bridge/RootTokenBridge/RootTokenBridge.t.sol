// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootTokenBridgeTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();

        // RootTokenBridge handle function is different from RootEscrowTokenBridge
        deployCodeTo(
            "src/root/bridge/RootTokenBridge.sol",
            abi.encode(
                rootTokenBridge.owner(),
                rootTokenBridge.xerc20(),
                rootTokenBridge.module(),
                rootTokenBridge.securityModule()
            ),
            address(rootTokenBridge)
        );
    }

    function test_InitialState() public view {
        assertEq(address(rootTokenBridge.lockbox()), address(rootLockbox));
        assertEq(address(rootTokenBridge.erc20()), address(rootRewardToken));
        assertEq(rootTokenBridge.module(), address(rootMessageModule));
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
