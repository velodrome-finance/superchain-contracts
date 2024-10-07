// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootBribeVotingRewardTest is BaseForkFixture {
    function test_InitialState() public view {
        assertEq(rootIVR.factory(), address(rootVotingRewardsFactory));
        assertEq(rootIVR.bridge(), address(rootMessageBridge));
        assertEq(rootIVR.voter(), address(mockVoter));
        assertEq(rootIVR.ve(), address(mockEscrow));
        assertEq(rootIVR.gauge(), address(rootGauge));
        assertEq(rootIVR.chainid(), leaf);
    }
}
