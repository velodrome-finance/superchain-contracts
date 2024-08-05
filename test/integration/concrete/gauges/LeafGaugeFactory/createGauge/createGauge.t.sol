// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafGaugeFactory.t.sol";

contract CreateGaugeIntegrationConcreteTest is LeafGaugeFactoryTest {
    address public leafPool;

    function setUp() public override {
        super.setUp();

        leafPool = destinationPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false});
    }

    function test_WhenTheCallerIsNotVoter() external {
        // It reverts with NotVoter
        // TODO: complete
    }

    function test_WhenTheCallerIsVoter() external {
        // It creates a new gauge
        LeafGauge leafGauge = LeafGauge(
            destinationLeafGaugeFactory.createGauge({
                _token0: address(token0),
                _token1: address(token1),
                _stable: false,
                _feesVotingReward: address(0),
                isPool: true
            })
        );

        // TODO: complete
        assertEq(leafGauge.stakingToken(), leafPool);
        // assertEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(destinationXVelo));
        // assertEq(leafGauge.bridge(), address(destinationBridge));
    }
}
