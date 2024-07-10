// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract MintUnitConcreteTest is XERC20Test {
    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimitOfCaller() external {
        // It should revert with IXERC20_NotHighEnoughLimits
        vm.prank(bridge);
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        xVelo.mint(users.alice, TOKEN_1);
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimitOfCaller() external {
        // It mints the requested amount of tokens to the user
        // It decreases the current minting limit for the caller
        // It should emit a {Transfer} event
        uint256 mintingLimit = 10_000 * TOKEN_1;
        uint256 burningLimit = 5_000 * TOKEN_1;
        vm.startPrank(users.owner);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: burningLimit});

        vm.startPrank(bridge);
        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: address(0), to: users.alice, value: TOKEN_1});
        xVelo.mint(users.alice, TOKEN_1);

        (IXERC20.BridgeParameters memory bpm, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        assertEq(xVelo.balanceOf(users.alice), TOKEN_1);
        assertEq(bpm.maxLimit, mintingLimit);
        assertEq(bpm.currentLimit, mintingLimit - TOKEN_1);
        assertEq(bpm.ratePerSecond, mintingLimit / DAY);
        assertEq(bpm.timestamp, block.timestamp);
        assertEq(bpb.maxLimit, burningLimit);
        assertEq(bpb.currentLimit, burningLimit);
        assertEq(bpb.ratePerSecond, burningLimit / DAY);
        assertEq(bpb.timestamp, block.timestamp);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit - TOKEN_1);
        assertEq(xVelo.mintingMaxLimitOf(bridge), mintingLimit);
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
        assertEq(xVelo.burningMaxLimitOf(bridge), burningLimit);
    }
}
