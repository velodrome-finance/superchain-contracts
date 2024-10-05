// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../EmergencyCouncilE2E.t.sol";

contract KillLeafGaugeE2ETest is EmergencyCouncilE2ETest {
    using stdStorage for StdStorage;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        emergencyCouncil.killLeafGauge(address(leafGauge));
    }

    modifier whenCallerIsOwner() {
        vm.startPrank({msgSender: users.owner, txOrigin: users.owner});
        _;
    }

    function test_WhenGaugeIsNotAlive() external whenCallerIsOwner {
        // It should revert with GaugeAlreadyKilled
        stdstore.target(address(mockVoter)).sig("isAlive(address)").with_key(address(leafGauge)).checked_write(false);
        vm.expectRevert(IVoter.GaugeAlreadyKilled.selector);
        emergencyCouncil.killLeafGauge(address(leafGauge));
    }

    modifier whenGaugeIsAlive() {
        assertEq(mockVoter.isAlive(address(leafGauge)), true);
        _;
    }

    function test_GivenClaimableIsGreaterThanZero() external whenCallerIsOwner whenGaugeIsAlive {
        // It should transfer claimable to minter
        // It should set claimable to zero
        // It should set isAlive as false for gauge
        // It should emit a {GaugeKilled} event

        // It should encode gauge address
        // It should forward the message to the voter on the leaf chain
        // It should set isAlive as false for gauge on the leaf voter
        // It should unwhitelist gauge tokens on leaf chain
        // It should emit a {GaugeKilled} event on the leaf chain

        uint256 balanceOfMinterBefore = rootRewardToken.balanceOf(mockVoter.minter());
        uint256 claimable = TOKEN_1 * 10;
        address minter = mockVoter.minter();
        deal({token: address(rootRewardToken), to: address(mockVoter), give: claimable});
        stdstore.target(address(mockVoter)).sig("claimable(address)").with_key(address(leafGauge)).checked_write(
            claimable
        );

        bytes memory payload = abi.encode(leafGauge);
        bytes memory message = abi.encode(Commands.KILL_GAUGE, payload);

        vm.expectEmit(address(mockVoter));
        emit IVoter.GaugeKilled({gauge: address(leafGauge)});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: MESSAGE_FEE,
            _message: string(message)
        });
        emergencyCouncil.killLeafGauge(address(leafGauge));

        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(minter) - balanceOfMinterBefore, claimable);
        assertEq(mockVoter.isAlive(address(leafGauge)), false);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafVoter));
        emit IVoter.GaugeKilled({gauge: address(leafGauge)});
        leafMailbox.processNextInboundMessage();

        assertFalse(leafVoter.isAlive(address(leafGauge)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 1);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), 0);
    }

    function test_GivenClaimableIsZero() external whenCallerIsOwner whenGaugeIsAlive {
        // It should set isAlive as false for gauge
        // It should emit a {GaugeKilled} event
        // It should encode gauge address
        // It should forward the message to the voter on the leaf chain
        // It should set isAlive as false for gauge on the leaf voter
        // It should unwhitelist gauge tokens on leaf chain
        // It should emit a {GaugeKilled} event on the leaf chain

        uint256 balanceOfVoterBefore = rootRewardToken.balanceOf(address(mockVoter));
        bytes memory payload = abi.encode(leafGauge);
        bytes memory message = abi.encode(Commands.KILL_GAUGE, payload);

        vm.expectEmit(address(mockVoter));
        emit IVoter.GaugeKilled({gauge: address(leafGauge)});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: MESSAGE_FEE,
            _message: string(message)
        });
        emergencyCouncil.killLeafGauge(address(leafGauge));

        assertEq(rootRewardToken.balanceOf(address(mockVoter)) - balanceOfVoterBefore, 0);
        assertEq(mockVoter.isAlive(address(leafGauge)), false);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafVoter));
        emit IVoter.GaugeKilled({gauge: address(leafGauge)});
        leafMailbox.processNextInboundMessage();

        assertFalse(leafVoter.isAlive(address(leafGauge)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 1);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), 0);
    }
}
