// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract RootGaugeFactoryTest is BaseForkFixture {
    function test_InitialState() public view {
        assertEq(rootGaugeFactory.voter(), address(mockVoter));
        assertEq(rootGaugeFactory.xerc20(), address(rootXVelo));
        assertEq(rootGaugeFactory.lockbox(), address(rootLockbox));
        assertEq(rootGaugeFactory.messageBridge(), address(rootMessageBridge));
        assertEq(rootGaugeFactory.votingRewardsFactory(), address(rootVotingRewardsFactory));
        assertEq(rootGaugeFactory.notifyAdmin(), users.owner);
    }
}
