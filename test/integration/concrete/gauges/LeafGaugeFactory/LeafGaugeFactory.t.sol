// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract LeafGaugeFactoryTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: destinationId});
    }

    function test_InitialState() public view {
        // assertEq(destinationLeafGaugeFactory.voter(), address(mockVoter));
        assertEq(destinationLeafGaugeFactory.xerc20(), address(originXVelo));
        assertEq(destinationLeafGaugeFactory.factory(), address(destinationPoolFactory));
        assertEq(destinationLeafGaugeFactory.bridge(), address(destinationBridge));
    }
}
