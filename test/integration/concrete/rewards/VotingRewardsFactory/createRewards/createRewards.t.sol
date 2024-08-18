// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../VotingRewardsFactory.t.sol";

contract CreateRewardsIntegrationConcreteTest is VotingRewardsFactoryTest {
    function test_WhenCallerIsNotVoter() external {
        // It reverts with {NotVoter}
        vm.prank(users.charlie);
        vm.expectRevert(IVotingRewardsFactory.NotVoter.selector);
        leafVotingRewardsFactory.createRewards({_rewards: new address[](0)});
    }

    function test_WhenCallerIsVoter() external {
        // It creates a new fee rewards contract with CREATE
        // It creates a new voting rewards contract with CREATE
        address[] memory rewards = new address[](2);
        rewards[0] = address(token0);
        rewards[1] = address(token1);

        vm.prank(address(leafVoter));
        (address fvr, address ivr) = leafVotingRewardsFactory.createRewards({_rewards: rewards});

        assertGt(fvr.code.length, 0);
        assertGt(ivr.code.length, 0);
    }
}
