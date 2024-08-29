// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootVotingRewardsFactory.t.sol";

contract CreateRewardsIntegrationConcreteTest is RootVotingRewardsFactoryTest {
    function test_WhenTheCallerIsAnyone() external {
        // It creates a new root fee rewards contract with CREATE
        // It creates a new root incentive rewards contract with CREATE
        address[] memory rewards = new address[](2);
        rewards[0] = address(token0);
        rewards[1] = address(token1);

        vm.prank(address(mockVoter));
        (address fvr, address ivr) = rootVotingRewardsFactory.createRewards(address(0), rewards);

        assertGt(fvr.code.length, 0);
        assertGt(ivr.code.length, 0);
    }
}
