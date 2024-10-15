// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafGaugeFactory.t.sol";

contract CreateGaugeIntegrationFuzzTest is LeafGaugeFactoryTest {
    function setUp() public override {
        super.setUp();

        // we use stable = true to avoid collision with existing pool
        leafPool = Pool(leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
    }

    function testFuzz_WhenTheCallerIsNotVoter(address _caller) external {
        // It reverts with NotVoter
        vm.assume(_caller != address(leafVoter));

        vm.prank(users.charlie);
        vm.expectRevert(ILeafGaugeFactory.NotVoter.selector);
        leafGaugeFactory.createGauge({_pool: address(leafPool), _feesVotingReward: address(0), isPool: true});
    }

    function testFuzz_WhenTheCallerIsVoter(address _fvr, bool _isPool) external {
        // It creates a new gauge
        vm.prank(address(leafVoter));
        LeafGauge leafGauge = LeafGauge(
            leafGaugeFactory.createGauge({_pool: address(leafPool), _feesVotingReward: _fvr, isPool: _isPool})
        );

        assertEq(leafGauge.stakingToken(), address(leafPool));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.feesVotingReward(), _fvr);
        assertEq(leafGauge.voter(), address(leafVoter));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));
        assertEq(leafGauge.isPool(), _isPool);
    }
}
