// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract KillGaugeIntegrationConcreteTest is LeafVoterTest {
    function test_WhenCallerIsNotTheModuleSetOnTheBridge() external {
        // It should revert with NotAuthorized
        vm.expectRevert(ILeafVoter.NotAuthorized.selector);
        vm.prank(users.charlie);
        leafVoter.killGauge(address(leafGauge));
    }

    modifier whenCallerIsTheModuleSetOnTheBridge() {
        vm.startPrank(address(leafMessageModule));
        _;
    }

    function test_WhenAddressIsNotALiveGauge() external whenCallerIsTheModuleSetOnTheBridge {
        // It should revert with GaugeAlreadyKilled
        vm.expectRevert(ILeafVoter.GaugeAlreadyKilled.selector);
        leafVoter.killGauge(address(leafPool));
    }

    modifier whenAddressIsALiveGauge() {
        _;
    }

    function test_WhenWhitelistCountOfGaugeTokensIsEqualTo1()
        external
        whenCallerIsTheModuleSetOnTheBridge
        whenAddressIsALiveGauge
    {
        // It should set isAlive for gauge to false
        // It should remove gauge tokens from set of whitelisted tokens
        // It should set whitelistTokenCount of gauge tokens to 0
        // It should emit a {WhitelistToken} event
        // It should emit a {GaugeKilled} event
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({whitelister: address(leafMessageModule), token: address(token0), _bool: false});
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({whitelister: address(leafMessageModule), token: address(token1), _bool: false});
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.GaugeKilled({gauge: address(leafGauge)});
        leafVoter.killGauge(address(leafGauge));

        assertFalse(leafVoter.isAlive(address(leafGauge)));
        assertFalse(leafVoter.isWhitelistedToken(address(token0)));
        assertFalse(leafVoter.isWhitelistedToken(address(token1)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 0);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), 0);
    }

    function test_WhenWhitelistCountOfGaugeTokensIsGreaterThan1()
        external
        whenCallerIsTheModuleSetOnTheBridge
        whenAddressIsALiveGauge
    {
        // create new gauge with same tokens to increase whitelistTokenCount
        leafPool = Pool(leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));
        vm.startPrank(address(leafMessageModule));
        leafGauge = LeafGauge(
            leafVoter.createGauge({
                _poolFactory: address(leafPoolFactory),
                _pool: address(leafPool),
                _votingRewardsFactory: address(leafVotingRewardsFactory),
                _gaugeFactory: address(leafGaugeFactory)
            })
        );

        // It should set isAlive for gauge to false
        // It should keep gauge tokens in set of whitelisted tokens
        // It should decrement the whitelistTokenCount count of gauge tokens by 1
        // It should emit a {WhitelistToken} event
        // It should emit a {GaugeKilled} event
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({whitelister: address(leafMessageModule), token: address(token0), _bool: false});
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({whitelister: address(leafMessageModule), token: address(token1), _bool: false});
        vm.expectEmit(address(leafVoter));
        vm.startPrank(address(leafMessageModule));
        emit ILeafVoter.GaugeKilled({gauge: address(leafGauge)});
        leafVoter.killGauge(address(leafGauge));

        assertFalse(leafVoter.isAlive(address(leafGauge)));
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(token1)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 1);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), 1);
    }
}
