// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract LeafGaugeFactoryTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: leafId});
    }

    function test_InitialState() public view {
        assertEq(leafGaugeFactory.voter(), address(leafVoter));
        assertEq(leafGaugeFactory.xerc20(), address(rootXVelo));
        assertEq(leafGaugeFactory.bridge(), address(leafMessageBridge));
        assertEq(leafGaugeFactory.notifyAdmin(), users.owner);
    }
}
