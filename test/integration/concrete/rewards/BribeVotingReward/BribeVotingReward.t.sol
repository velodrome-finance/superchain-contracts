// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract BribeVotingRewards is BaseForkFixture {
    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_InitialState() public {
        assertEq(leafIVR.voter(), address(leafVoter));
        assertEq(leafIVR.authorized(), address(leafMessageBridge));
    }
}
