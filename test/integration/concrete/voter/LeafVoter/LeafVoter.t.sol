// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract LeafVoterTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: leafId});
        address incentivePool = leafPoolFactory.getPool({tokenA: address(token0), tokenB: address(weth), stable: false});
        address incentiveGauge = leafVoter.gauges(incentivePool);
        // Disable Incentive Gauge to keep the same `whitelistTokenCount` in both tokens
        vm.prank(address(leafMessageModule));
        leafVoter.killGauge(incentiveGauge);
    }

    function test_InitialState() public view {
        assertEq(leafVoter.bridge(), address(leafMessageBridge));
        assertTrue(leafVoter.isAlive(address(leafGauge)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 1);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), 1);
    }
}
