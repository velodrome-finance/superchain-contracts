// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract CreateGaugeIntegrationConcreteTest is RootGaugeFactoryTest {
    function setUp() public override {
        super.setUp();

        // we use stable = true to avoid collision with existing pool
        rootPool =
            RootPool(rootPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
    }

    function test_WhenTheCallerIsNotVoter() external {
        // It reverts with NotVoter
        vm.prank(users.charlie);
        vm.expectRevert(IRootGaugeFactory.NotVoter.selector);
        rootGaugeFactory.createGauge(address(0), address(rootPool), address(0), address(rootRewardToken), true);
    }

    function test_WhenTheCallerIsVoter() external {
        // It creates a new gauge
        address rootFVR = address(
            new RootFeesVotingReward({
                _bridge: address(rootBridge),
                _voter: address(mockVoter),
                _rewards: new address[](0)
            })
        );

        vm.prank(address(mockVoter));
        RootGauge rootGauge = RootGauge(
            rootGaugeFactory.createGauge(
                address(0), address(rootPool), address(rootFVR), address(rootRewardToken), true
            )
        );

        assertEq(rootGauge.rewardToken(), address(rootRewardToken));
        assertEq(rootGauge.xerc20(), address(rootXVelo));
        assertEq(rootGauge.lockbox(), address(rootLockbox));
        assertEq(rootGauge.bridge(), address(rootBridge));
        assertEq(rootGauge.chainid(), leaf);
    }
}
