// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";
import "src/interfaces/external/IVoter.sol";

abstract contract IncentiveVotingRewardTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_InitialState() public view {
        assertEq(leafIVR.voter(), address(leafVoter));
        assertEq(leafIVR.authorized(), address(leafMessageBridge));
    }
}
