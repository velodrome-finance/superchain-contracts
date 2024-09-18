// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract MintUnitConcreteTest is XERC20Test {
    using SafeCast for uint256;

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimitOfCaller() external {
        // It should revert with "RateLimited: rate limit hit"
        vm.prank(bridge);
        vm.expectRevert("RateLimited: rate limit hit");
        xVelo.mint(users.alice, TOKEN_1);
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimitOfCaller() external {
        // It mints the requested amount of tokens to the user
        // It decreases the current minting limit for the caller
        // It should emit a {Transfer} event
        uint256 bufferCap = 10_000 * TOKEN_1;
        uint256 rps = (bufferCap / 2) / DAY;
        vm.startPrank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: bridge,
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(bridge);
        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: address(0), to: users.alice, value: TOKEN_1});
        xVelo.mint(users.alice, TOKEN_1);

        RateLimitMidPoint memory limit = xVelo.rateLimits(bridge);
        assertEq(xVelo.balanceOf(users.alice), TOKEN_1);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint - TOKEN_1);

        assertEq(xVelo.mintingCurrentLimitOf(bridge), limit.midPoint - TOKEN_1);
        assertEq(xVelo.mintingMaxLimitOf(bridge), bufferCap);
        assertEq(xVelo.burningCurrentLimitOf(bridge), limit.midPoint + TOKEN_1);
        assertEq(xVelo.burningMaxLimitOf(bridge), bufferCap);
    }
}
