// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootGaugeTest is BaseForkFixture {
    function test_InitialState() public view {
        assertEq(rootGauge.rewardToken(), address(rootRewardToken));
        assertEq(rootGauge.xerc20(), address(rootXVelo));
        assertEq(rootGauge.voter(), address(mockVoter));
        assertEq(rootGauge.lockbox(), address(rootLockbox));
        assertEq(rootGauge.bridge(), address(rootMessageBridge));
        assertEq(rootGauge.chainid(), leaf);
    }
}
