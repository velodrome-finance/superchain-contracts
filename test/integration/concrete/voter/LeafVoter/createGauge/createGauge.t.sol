// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract CreateGaugeIntegrationConcreteTest is LeafVoterTest {
    function setUp() public override {
        super.setUp();

        // we use stable = true to avoid collision with existing pool
        leafPool = Pool(leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
    }

    function test_WhenCallerIsNotBridgeModule() external {
        // It should revert with NotAuthorized
        vm.prank(users.charlie);
        vm.expectRevert(ILeafVoter.NotAuthorized.selector);
        leafGauge = LeafGauge(
            leafVoter.createGauge({
                _poolFactory: address(leafPoolFactory),
                _pool: address(leafPool),
                _votingRewardsFactory: address(leafVotingRewardsFactory),
                _gaugeFactory: address(leafGaugeFactory)
            })
        );
    }

    function test_WhenCallerIsBridgeModule() external {
        // It should create new gauge
        // It should set gaugeToFees for new gauge
        // It should set gaugeToIncentive for new gauge
        // It should set gauges for given pool to new gauge
        // It should set poolForGauge for new gauge to given pool
        // It should set isGauge for new gauge to true
        // It should set isAlive for new gauge to true
        // It should add given pool to pools
        // It should whitelist both tokens of pool
        // It should emit {GaugeCreated} event
        vm.prank(address(leafMessageModule));
        vm.expectEmit(true, true, true, false, address(leafVoter));
        emit ILeafVoter.GaugeCreated({
            poolFactory: address(leafPoolFactory),
            votingRewardsFactory: address(leafVotingRewardsFactory),
            gaugeFactory: address(leafGaugeFactory),
            pool: address(0),
            incentiveVotingReward: address(0),
            feeVotingReward: address(0),
            gauge: address(0)
        });
        leafGauge = LeafGauge(
            leafVoter.createGauge({
                _poolFactory: address(leafPoolFactory),
                _pool: address(leafPool),
                _votingRewardsFactory: address(leafVotingRewardsFactory),
                _gaugeFactory: address(leafGaugeFactory)
            })
        );

        assertNotEq(leafVoter.gaugeToFees(address(leafGauge)), address(0));
        assertNotEq(leafVoter.gaugeToIncentive(address(leafGauge)), address(0));
        assertEq(leafVoter.gauges(address(leafPool)), address(leafGauge));
        assertEq(leafVoter.poolForGauge(address(leafGauge)), address(leafPool));
        assertTrue(leafVoter.isGauge(address(leafGauge)));
        assertTrue(leafVoter.isAlive(address(leafGauge)));
        assertEq(leafVoter.pools(2), address(leafPool));
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(token1)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 2);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), 2);
    }
}
