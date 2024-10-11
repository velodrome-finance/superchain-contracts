// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract KillGaugeIntegrationFuzzTest is LeafVoterTest {
    using stdStorage for StdStorage;

    function testFuzz_WhenCallerIsNotTheModuleSetOnTheBridge(address _caller) external {
        vm.assume(_caller != address(leafMessageModule));
        // It should revert with NotAuthorized
        vm.expectRevert(ILeafVoter.NotAuthorized.selector);
        vm.prank(_caller);
        leafVoter.killGauge(address(leafGauge));
    }

    modifier whenCallerIsTheModuleSetOnTheBridge() {
        vm.startPrank(address(leafMessageModule));
        _;
    }

    function testFuzz_WhenAddressIsNotALiveGauge(address _gauge) external whenCallerIsTheModuleSetOnTheBridge {
        vm.assume(_gauge != address(leafGauge) && _gauge != address(incentiveGauge));
        // It should revert with GaugeAlreadyKilled
        vm.expectRevert(ILeafVoter.GaugeAlreadyKilled.selector);
        leafVoter.killGauge(_gauge);
    }

    modifier whenAddressIsALiveGauge() {
        _;
    }

    function testFuzz_WhenWhitelistCountOfGaugeTokensIsGreaterThan1(uint256 _whitelistCount0, uint256 _whitelistCount1)
        external
        whenCallerIsTheModuleSetOnTheBridge
        whenAddressIsALiveGauge
    {
        _whitelistCount0 = bound(_whitelistCount0, 2, type(uint256).max);
        _whitelistCount1 = bound(_whitelistCount1, 2, type(uint256).max);
        stdstore.target(address(leafVoter)).sig("whitelistTokenCount(address)").with_key(address(token0)).checked_write(
            _whitelistCount0
        );
        stdstore.target(address(leafVoter)).sig("whitelistTokenCount(address)").with_key(address(token1)).checked_write(
            _whitelistCount1
        );

        // It should set isAlive for gauge to false
        // It should keep gauge tokens in set of whitelisted tokens
        // It should decrement the whitelistTokenCount count of gauge tokens by 1
        // It should emit a {WhitelistToken} event
        // It should emit a {GaugeKilled} event
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({token: address(token0), _bool: false});
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({token: address(token1), _bool: false});
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.GaugeKilled({gauge: address(leafGauge)});
        leafVoter.killGauge(address(leafGauge));

        assertFalse(leafVoter.isAlive(address(leafGauge)));
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(token1)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), _whitelistCount0 - 1);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), _whitelistCount1 - 1);
    }
}
