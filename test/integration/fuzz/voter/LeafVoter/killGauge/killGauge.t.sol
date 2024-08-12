// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract KillGaugeIntegrationFuzzTest is LeafVoterTest {
    using stdStorage for StdStorage;

    function testFuzz_WhenCallerIsNotEmergencyCouncil(address caller) external {
        vm.assume(caller != leafVoter.emergencyCouncil());
        // It should revert with NotEmergencyCouncil
        vm.expectRevert(ILeafVoter.NotEmergencyCouncil.selector);
        vm.prank(caller);
        leafVoter.killGauge(address(leafGauge));
    }

    modifier whenCallerIsEmergencyCouncil() {
        vm.startPrank(leafVoter.emergencyCouncil());
        _;
    }

    function testFuzz_WhenAddressIsNotALiveGauge(address gauge) external whenCallerIsEmergencyCouncil {
        vm.assume(gauge != address(leafGauge));
        // It should revert with GaugeAlreadyKilled
        vm.expectRevert(ILeafVoter.GaugeAlreadyKilled.selector);
        leafVoter.killGauge(gauge);
    }

    modifier whenAddressIsALiveGauge() {
        _;
    }

    function testFuzz_WhenWhitelistCountOfGaugeTokensIsGreaterThan1(uint256 whitelistCount0, uint256 whitelistCount1)
        external
        whenCallerIsEmergencyCouncil
        whenAddressIsALiveGauge
    {
        whitelistCount0 = bound(whitelistCount0, 2, type(uint256).max);
        whitelistCount1 = bound(whitelistCount1, 2, type(uint256).max);
        stdstore.target(address(leafVoter)).sig("whitelistTokenCount(address)").with_key(address(token0)).checked_write(
            whitelistCount0
        );
        stdstore.target(address(leafVoter)).sig("whitelistTokenCount(address)").with_key(address(token1)).checked_write(
            whitelistCount1
        );

        // It should set isAlive for gauge to false
        // It should keep gauge tokens in set of whitelisted tokens
        // It should decrement the whitelistTokenCount count of gauge tokens by 1
        // It should emit a {WhitelistToken} event
        // It should emit a {GaugeKilled} event
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({
            whitelister: address(leafVoter.emergencyCouncil()),
            token: address(token0),
            _bool: false
        });
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({
            whitelister: address(leafVoter.emergencyCouncil()),
            token: address(token1),
            _bool: false
        });
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.GaugeKilled({gauge: address(leafGauge)});
        leafVoter.killGauge(address(leafGauge));

        assertFalse(leafVoter.isAlive(address(leafGauge)));
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(token1)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), whitelistCount0 - 1);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), whitelistCount1 - 1);
    }
}
