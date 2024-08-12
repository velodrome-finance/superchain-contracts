// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafVoter.t.sol";

contract ReviveGaugeIntegrationFuzzTest is LeafVoterTest {
    using stdStorage for StdStorage;

    function testFuzz_WhenCallerIsNotEmergencyCouncil(address caller) external {
        vm.assume(caller != leafVoter.emergencyCouncil());
        // It should revert with NotEmergencyCouncil
        vm.expectRevert(ILeafVoter.NotEmergencyCouncil.selector);
        vm.prank(caller);
        leafVoter.reviveGauge(address(leafGauge));
    }

    modifier whenCallerIsEmergencyCouncil() {
        vm.startPrank(leafVoter.emergencyCouncil());
        _;
    }

    function testFuzz_WhenAddressGivenIsNotAGauge(address gauge) external whenCallerIsEmergencyCouncil {
        vm.assume(gauge != address(leafGauge));
        // It should revert with NotAGauge
        vm.expectRevert(ILeafVoter.NotAGauge.selector);
        leafVoter.reviveGauge(gauge);
    }

    modifier whenAddressGivenIsAGauge() {
        _;
    }

    modifier whenGaugeIsNotAlive() {
        leafVoter.killGauge(address(leafGauge));
        _;
    }

    function testFuzz_WhenWhitelistCountOfGaugeTokensIsGreaterThan0(uint256 whitelistCount0, uint256 whitelistCount1)
        external
        whenCallerIsEmergencyCouncil
        whenAddressGivenIsAGauge
        whenGaugeIsNotAlive
    {
        // create new gauge with same tokens to increase whitelistTokenCount
        address newPool = leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true});
        LeafGauge(leafVoter.createGauge({_poolFactory: address(leafPoolFactory), _pool: newPool}));

        whitelistCount0 = bound(whitelistCount0, 1, type(uint256).max - 1);
        whitelistCount1 = bound(whitelistCount1, 1, type(uint256).max - 1);
        stdstore.target(address(leafVoter)).sig("whitelistTokenCount(address)").with_key(address(token0)).checked_write(
            whitelistCount0
        );
        stdstore.target(address(leafVoter)).sig("whitelistTokenCount(address)").with_key(address(token1)).checked_write(
            whitelistCount1
        );

        // It should set isAlive for gauge to true
        // It should keep gauge tokens in set of whitelisted tokens
        // It should increment the whitelistTokenCount of gauge tokens by 1
        // It should emit a {WhitelistToken} event
        // It should emit a {GaugeRevived} event
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({
            whitelister: address(leafVoter.emergencyCouncil()),
            token: address(token0),
            _bool: true
        });
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.WhitelistToken({
            whitelister: address(leafVoter.emergencyCouncil()),
            token: address(token1),
            _bool: true
        });
        vm.expectEmit(address(leafVoter));
        emit ILeafVoter.GaugeRevived({gauge: address(leafGauge)});
        leafVoter.reviveGauge(address(leafGauge));

        assertTrue(leafVoter.isAlive(address(leafGauge)));
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(token1)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), whitelistCount0 + 1);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), whitelistCount1 + 1);
    }
}
