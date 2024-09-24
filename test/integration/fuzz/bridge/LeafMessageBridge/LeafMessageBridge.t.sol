// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract LeafMessageBridgeTest is BaseForkFixture {
    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }
}
