// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafGaugeFactory.t.sol";

contract CreateGaugeIntegrationConcreteTest is LeafGaugeFactoryTest {
    function setUp() public override {
        super.setUp();

        // we use stable = true to avoid collision with existing pool
        leafPool = Pool(leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
    }

    function test_WhenTheCallerIsNotVoter() external {
        // It reverts with NotVoter
        // TODO: complete
    }

    function test_WhenTheCallerIsVoter() external {
        // It creates a new gauge
        LeafGauge leafGauge = LeafGauge(
            leafGaugeFactory.createGauge({
                _token0: address(token0),
                _token1: address(token1),
                _stable: true,
                _feesVotingReward: address(0),
                isPool: true
            })
        );

        // TODO: complete
        assertEq(leafGauge.stakingToken(), address(leafPool));
        // assertEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        // assertEq(leafGauge.bridge(), address(leafBridge));
    }
}
