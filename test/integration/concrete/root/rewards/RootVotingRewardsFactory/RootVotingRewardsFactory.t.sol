// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootVotingRewardsFactoryTest is BaseForkFixture {
    function test_InitialState() public view {
        assertEq(rootVotingRewardsFactory.bridge(), address(rootMessageBridge));
    }
}
