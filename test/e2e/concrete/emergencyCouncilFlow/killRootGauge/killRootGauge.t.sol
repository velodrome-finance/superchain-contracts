// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../EmergencyCouncilE2E.t.sol";

contract KillRootGaugeE2ETest is EmergencyCouncilE2ETest {
    using stdStorage for StdStorage;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        emergencyCouncil.killRootGauge(address(rootGauge));
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenGaugeIsNotAlive() external whenCallerIsOwner {
        // It should revert with GaugeAlreadyKilled
        stdstore.target(address(mockVoter)).sig("isAlive(address)").with_key(address(rootGauge)).checked_write(false);
        vm.expectRevert(IVoter.GaugeAlreadyKilled.selector);
        emergencyCouncil.killRootGauge(address(rootGauge));
    }

    modifier whenGaugeIsAlive() {
        assertEq(mockVoter.isAlive(address(rootGauge)), true);
        _;
    }

    function test_GivenClaimableIsGreaterThanZero() external whenCallerIsOwner whenGaugeIsAlive {
        // It should transfer claimable to minter
        // It should set claimable to zero
        // It should set isAlive as false for gauge
        // It should emit a {GaugeKilled} event

        uint256 balanceOfMinterBefore = rootRewardToken.balanceOf(mockVoter.minter());
        uint256 claimable = TOKEN_1 * 10;
        address minter = mockVoter.minter();
        deal({token: address(rootRewardToken), to: address(mockVoter), give: claimable});
        stdstore.target(address(mockVoter)).sig("claimable(address)").with_key(address(rootGauge)).checked_write(
            claimable
        );

        vm.expectEmit(address(mockVoter));
        emit IVoter.GaugeKilled({gauge: address(rootGauge)});
        emergencyCouncil.killRootGauge(address(rootGauge));

        assertEq(rootRewardToken.balanceOf(address(mockVoter)), 0);
        assertEq(rootRewardToken.balanceOf(minter) - balanceOfMinterBefore, claimable);
        assertEq(mockVoter.isAlive(address(rootGauge)), false);
    }

    function test_GivenClaimableIsZero() external whenCallerIsOwner whenGaugeIsAlive {
        // It should set isAlive as false for gauge
        // It should emit a {GaugeKilled} event

        assertEq(mockVoter.claimable(address(rootGauge)), 0);

        vm.expectEmit(address(mockVoter));
        emit IVoter.GaugeKilled({gauge: address(rootGauge)});
        emergencyCouncil.killRootGauge(address(rootGauge));

        assertEq(mockVoter.isAlive(address(rootGauge)), false);
    }
}