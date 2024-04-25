// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../../BaseFixture.sol";

contract StakingRewardsFactoryTest is BaseFixture {
    function setUp() public override {
        super.setUp();
    }

    function test_InitialState() public view {
        assertEq(stakingRewardsFactory.notifyAdmin(), address(users.owner));
    }
}
