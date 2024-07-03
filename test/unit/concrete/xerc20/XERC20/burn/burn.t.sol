// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract BurnUnitConcreteTest is XERC20Test {
    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller() external {
        // It should revert with IXERC20_NotHighEnoughLimits
        xVelo.setLimits({_bridge: bridge, _mintingLimit: TOKEN_1, _burningLimit: 0});

        vm.prank(bridge);
        xVelo.mint(users.alice, TOKEN_1);

        vm.prank(users.alice);
        xVelo.approve(bridge, TOKEN_1);

        vm.prank(bridge);
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        xVelo.burn(bridge, TOKEN_1);
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() external {
        // It burns the requested amount of tokens
        // It decreases the current burning limit for the caller
        // It decreases the allowance of the caller by the requested amount
        // It should emit a {Transfer} event
        uint256 mintingLimit = 10_000 * TOKEN_1;
        uint256 burningLimit = 5_000 * TOKEN_1;
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: burningLimit});

        vm.prank(bridge);
        xVelo.mint(users.alice, TOKEN_1);

        vm.prank(users.alice);
        xVelo.approve(bridge, TOKEN_1);

        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: users.alice, to: address(0), value: TOKEN_1});
        vm.prank(bridge);
        xVelo.burn(users.alice, TOKEN_1);

        (IXERC20.BridgeParameters memory bpm, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        assertEq(xVelo.balanceOf(bridge), 0);
        assertEq(xVelo.allowance(bridge, address(xVelo)), 0);
        assertEq(bpm.maxLimit, mintingLimit);
        assertEq(bpm.currentLimit, mintingLimit - TOKEN_1);
        assertEq(bpm.ratePerSecond, mintingLimit / DAY);
        assertEq(bpm.timestamp, block.timestamp);
        assertEq(bpb.maxLimit, burningLimit);
        assertEq(bpb.currentLimit, burningLimit - TOKEN_1);
        assertEq(bpb.ratePerSecond, burningLimit / DAY);
        assertEq(bpb.timestamp, block.timestamp);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit - TOKEN_1);
        assertEq(xVelo.mintingMaxLimitOf(bridge), mintingLimit);
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit - TOKEN_1);
        assertEq(xVelo.burningMaxLimitOf(bridge), burningLimit);
    }
}
