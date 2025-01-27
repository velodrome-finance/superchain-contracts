// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootTokenBridgeTest is BaseForkFixture {
    function setUp() public override {
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
}
