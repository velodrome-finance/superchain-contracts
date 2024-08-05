// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootGaugeFactory.t.sol";

contract CreateGaugeIntegrationConcreteTest is RootGaugeFactoryTest {
    address public rootPool;

    function setUp() public override {
        super.setUp();

        rootPool = originRootPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false});
    }

    function test_WhenTheCallerIsNotVoter() external {
        // It reverts with NotVoter
        vm.prank(users.charlie);
        vm.expectRevert(IRootGaugeFactory.NotVoter.selector);
        originRootGaugeFactory.createGauge(address(0), rootPool, address(0), address(originRewardToken), true);
    }

    function test_WhenTheCallerIsVoter() external {
        // It creates a new gauge
        vm.prank(address(mockVoter));
        RootGauge rootGauge = RootGauge(
            originRootGaugeFactory.createGauge(address(0), rootPool, address(0), address(originRewardToken), true)
        );

        assertEq(rootGauge.rewardToken(), address(originRewardToken));
        assertEq(rootGauge.xerc20(), address(originXVelo));
        assertEq(rootGauge.lockbox(), address(originLockbox));
        assertEq(rootGauge.bridge(), address(originBridge));
        assertEq(rootGauge.chainid(), destination);
    }
}
