// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../EmergencyCouncilE2E.t.sol";

contract ReviveLeafGaugeE2ETest is EmergencyCouncilE2ETest {
    using stdStorage for StdStorage;
    using GasLimits for uint256;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        emergencyCouncil.reviveLeafGauge(gauge);
    }

    modifier whenCallerIsOwner() {
        vm.startPrank({msgSender: users.owner, txOrigin: users.owner});
        _;
    }

    function test_WhenGaugeIsNotAGauge() external whenCallerIsOwner {
        // It should revert with InvalidGauge
        vm.expectRevert(IEmergencyCouncil.InvalidGauge.selector);
        emergencyCouncil.reviveLeafGauge(gauge);
    }

    modifier whenGaugeIsAGauge() {
        gauge = address(rootGauge);
        _;
    }

    function test_WhenGaugeIsAlive() external whenCallerIsOwner whenGaugeIsAGauge {
        // It should revert with GaugeAlreadyRevived
        vm.expectRevert(IVoter.GaugeAlreadyRevived.selector);
        emergencyCouncil.reviveLeafGauge(address(leafGauge));
    }

    function test_WhenGaugeIsNotAlive() external whenCallerIsOwner whenGaugeIsAGauge {
        // It should set isAlive as true for gauge
        // It should emit a {GaugeRevived} event
        // It should set isAlive as true for gauge on leaf voter
        // It should add gauge tokens to set of whitelisted tokens
        // It should emit a {GaugeRevived} event

        bytes memory message = abi.encodePacked(uint8(Commands.REVIVE_GAUGE), gauge);

        stdstore.target(address(mockVoter)).sig("isAlive(address)").with_key(gauge).checked_write(false);
        vm.expectEmit(address(mockVoter));
        emit IVoter.GaugeRevived({gauge: gauge});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leafDomain,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: MESSAGE_FEE,
            _message: string(message),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: MESSAGE_FEE,
                    _gasLimit: Commands.REVIVE_GAUGE.gasLimit(),
                    _refundAddress: users.owner,
                    _customMetadata: ""
                })
            )
        });
        emergencyCouncil.reviveLeafGauge(gauge);

        assertEq(mockVoter.isAlive(gauge), true);

        vm.selectFork({forkId: leafId});
        stdstore.target(address(leafVoter)).sig("isAlive(address)").with_key(gauge).checked_write(false);
        vm.expectEmit(address(leafVoter));
        emit IVoter.GaugeRevived({gauge: gauge});
        leafMailbox.processNextInboundMessage();

        assertTrue(leafVoter.isAlive(gauge));
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(token1)));
    }
}
