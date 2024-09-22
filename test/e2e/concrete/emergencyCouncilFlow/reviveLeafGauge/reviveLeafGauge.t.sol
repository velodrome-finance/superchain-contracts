// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../EmergencyCouncilE2E.t.sol";

contract ReviveLeafGaugeE2ETest is EmergencyCouncilE2ETest {
    using stdStorage for StdStorage;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        emergencyCouncil.reviveLeafGauge(leaf, address(leafGauge));
    }

    modifier whenCallerIsOwner() {
        vm.startPrank({msgSender: users.owner, txOrigin: users.owner});
        _;
    }

    function test_WhenGaugeIsAlive() external whenCallerIsOwner {
        // It should revert with GaugeAlreadyRevived
        vm.expectRevert(IVoter.GaugeAlreadyRevived.selector);
        emergencyCouncil.reviveLeafGauge(leaf, address(leafGauge));
    }

    function test_WhenGaugeIsNotAlive() external whenCallerIsOwner {
        // It should set isAlive as true for gauge
        // It should emit a {GaugeRevived} event
        // It should set isAlive as true for gauge on leaf voter
        // It should add gauge tokens to set of whitelisted tokens
        // It should emit a {GaugeRevived} event

        bytes memory payload = abi.encode(leafGauge);
        bytes memory message = abi.encode(Commands.REVIVE_GAUGE, payload);

        stdstore.target(address(mockVoter)).sig("isAlive(address)").with_key(address(leafGauge)).checked_write(false);
        vm.expectEmit(address(mockVoter));
        emit IVoter.GaugeRevived({gauge: address(leafGauge)});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: MESSAGE_FEE,
            _message: string(message)
        });
        emergencyCouncil.reviveLeafGauge(leaf, address(leafGauge));

        assertEq(mockVoter.isAlive(address(leafGauge)), true);

        vm.selectFork({forkId: leafId});
        stdstore.target(address(leafVoter)).sig("isAlive(address)").with_key(address(leafGauge)).checked_write(false);
        vm.expectEmit(address(leafVoter));
        emit IVoter.GaugeRevived({gauge: address(leafGauge)});
        leafMailbox.processNextInboundMessage();

        assertTrue(leafVoter.isAlive(address(leafGauge)));
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(token1)));
    }
}
