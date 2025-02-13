// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract ReviveGaugeIntegrationFuzzTest is LeafVoterTest {
    using stdStorage for StdStorage;

    function testFuzz_WhenCallerIsTheModuleSetOnTheBridge(address _caller) external {
        vm.assume(_caller != address(leafMessageModule));
        // It should revert with NotAuthorized
        vm.expectRevert(ILeafVoter.NotAuthorized.selector);
        vm.prank(_caller);
        leafVoter.reviveGauge(address(leafGauge));
    }

    modifier whenCallerIsTheModuleSetOnTheBridge() {
        vm.startPrank(address(leafMessageModule));
        _;
    }

    function testFuzz_WhenAddressGivenIsNotAGauge(address _gauge) external whenCallerIsTheModuleSetOnTheBridge {
        vm.assume(_gauge != address(leafGauge) && _gauge != address(incentiveGauge));
        // It should revert with NotAGauge
        vm.expectRevert(ILeafVoter.NotAGauge.selector);
        leafVoter.reviveGauge(_gauge);
    }

    modifier whenAddressGivenIsAGauge() {
        _;
    }

    modifier whenGaugeIsNotAlive() {
        leafVoter.killGauge(address(leafGauge));
        _;
    }

    function testFuzz_WhenWhitelistCountOfGaugeTokensIsGreaterThan0(uint256 _whitelistCount0, uint256 _whitelistCount1)
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

        _whitelistCount0 = bound(_whitelistCount0, 1, type(uint256).max - 1);
        _whitelistCount1 = bound(_whitelistCount1, 1, type(uint256).max - 1);
        stdstore.target(address(leafVoter)).sig("whitelistTokenCount(address)").with_key(address(token0)).checked_write(
            _whitelistCount0
        );
        stdstore.target(address(leafVoter)).sig("whitelistTokenCount(address)").with_key(address(token1)).checked_write(
            _whitelistCount1
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
        assertEq(leafVoter.whitelistTokenCount(address(token0)), _whitelistCount0 + 1);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), _whitelistCount1 + 1);
    }
}
