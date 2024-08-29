// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract FeesVotingRewardTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_InitialState() public view {
        assertEq(leafFVR.voter(), address(leafVoter));
        assertEq(leafFVR.authorized(), address(leafMessageBridge));
    }
}
