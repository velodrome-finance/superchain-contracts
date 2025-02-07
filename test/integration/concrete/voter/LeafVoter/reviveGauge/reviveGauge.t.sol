// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract ReviveGaugeIntegrationConcreteTest is LeafVoterTest {
    function test_WhenCallerIsNotTheModuleSetOnTheBridge() external {
        // It should revert with NotAuthorized
        vm.expectRevert(ILeafVoter.NotAuthorized.selector);
        vm.prank(users.charlie);
        leafVoter.reviveGauge(address(leafGauge));
    }

    modifier whenCallerIsTheModuleSetOnTheBridge() {
        vm.startPrank(address(leafMessageModule));
        _;
    }

    function test_WhenAddressGivenIsNotAGauge() external whenCallerIsTheModuleSetOnTheBridge {
        // It should revert with NotAGauge
        vm.expectRevert(ILeafVoter.NotAGauge.selector);
        leafVoter.reviveGauge(address(leafPool));
    }

    modifier whenAddressGivenIsAGauge() {
        _;
    }

    function test_WhenGaugeIsAlive() external whenCallerIsTheModuleSetOnTheBridge whenAddressGivenIsAGauge {
        // It should revert with GaugeAlreadyRevived
        vm.expectRevert(ILeafVoter.GaugeAlreadyRevived.selector);
        leafVoter.reviveGauge(address(leafGauge));
    }

    modifier whenGaugeIsNotAlive() {
        leafVoter.killGauge(address(leafGauge));
        _;
    }

    function test_WhenWhitelistCountOfGaugeTokensIsEqualTo0()
        external
        whenCallerIsTheModuleSetOnTheBridge
        whenAddressGivenIsAGauge
        whenGaugeIsNotAlive
    {
        // It should set isAlive for gauge to true
        // It should add gauge tokens to set of whitelisted tokens
        // It should set whitelistTokenCount of gauge tokens to 1
        // It should emit a {WhitelistToken} event
        // It should emit a {GaugeRevived} event
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({token: address(token0), _bool: true});
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({token: address(token1), _bool: true});
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.GaugeRevived({gauge: address(leafGauge)});
        leafVoter.reviveGauge(address(leafGauge));

        assertTrue(leafVoter.isAlive(address(leafGauge)));
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(token1)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 1);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), 1);
    }

    function test_WhenWhitelistCountOfGaugeTokensIsGreaterThan0()
        external
        whenCallerIsTheModuleSetOnTheBridge
        whenAddressGivenIsAGauge
        whenGaugeIsNotAlive
    {
        // create new gauge with same tokens to increase whitelistTokenCount
        address newPool = leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true});
        vm.startPrank(address(leafMessageModule));
        LeafGauge(
            leafVoter.createGauge({
                _poolFactory: address(leafPoolFactory),
                _pool: newPool,
                _votingRewardsFactory: address(leafVotingRewardsFactory),
                _gaugeFactory: address(leafGaugeFactory)
            })
        );

        // It should set isAlive for gauge to true
        // It should keep gauge tokens in set of whitelisted tokens
        // It should increment the whitelistTokenCount of gauge tokens by 1
        // It should emit a {WhitelistToken} event
        // It should emit a {GaugeRevived} event
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({token: address(token0), _bool: true});
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({token: address(token1), _bool: true});
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.GaugeRevived({gauge: address(leafGauge)});
        vm.startPrank(address(leafMessageModule));
        leafVoter.reviveGauge(address(leafGauge));

        assertTrue(leafVoter.isAlive(address(leafGauge)));
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(token1)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 2);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), 2);
    }
}
