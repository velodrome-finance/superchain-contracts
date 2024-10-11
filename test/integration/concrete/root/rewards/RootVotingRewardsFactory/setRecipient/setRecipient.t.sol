// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootVotingRewardsFactory.t.sol";

contract SetRecipientIntegrationConcreteTest is RootVotingRewardsFactoryTest {
    function test_WhenTheCallerIsAnyone() external {
        // It should set the recipient for the message sender
        // It should emit a {RecipientSet} event
        assertEq(rootVotingRewardsFactory.recipient({_owner: address(this), _chainid: 1}), address(0));

        vm.expectEmit(address(rootVotingRewardsFactory));
        emit IRootVotingRewardsFactory.RecipientSet({_caller: address(this), _chainid: 1, _recipient: address(this)});
        rootVotingRewardsFactory.setRecipient({_chainid: 1, _recipient: address(this)});

        assertEq(rootVotingRewardsFactory.recipient({_owner: address(this), _chainid: 1}), address(this));
    }
}
