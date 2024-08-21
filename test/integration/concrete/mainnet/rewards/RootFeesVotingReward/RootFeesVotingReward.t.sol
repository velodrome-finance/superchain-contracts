// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootFeesVotingRewardTest is BaseForkFixture {
    function test_InitialState() public view {
        assertEq(rootFVR.bridge(), address(rootMessageBridge));
        assertEq(rootFVR.voter(), address(mockVoter));
        assertEq(rootFVR.gauge(), address(rootGauge));
        assertEq(rootFVR.chainid(), leaf);
    }
}
