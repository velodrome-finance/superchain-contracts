// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract BurnUnitConcreteTest is XERC20Test {
    using SafeCast for uint256;

    function setUp() public override {
        super.setUp();

        vm.startPrank(users.owner);
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller() external {
        // It should revert with "RateLimited: buffer cap overflow"
        uint112 bufferCap = xVelo.minBufferCap() + 1;
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: bridge,
                bufferCap: bufferCap,
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        vm.startPrank(bridge);
        xVelo.mint(users.alice, TOKEN_1);
        uint256 burnAmount = bufferCap / 2 + TOKEN_1 + 2; // account for minted tokens

        vm.startPrank(users.alice);
        xVelo.approve(bridge, burnAmount);

        vm.startPrank(bridge);
        vm.expectRevert("RateLimited: buffer cap overflow");
        xVelo.burn(users.alice, burnAmount);
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() external {
        // It burns the requested amount of tokens
        // It decreases the current burning limit for the caller
        // It decreases the allowance of the caller by the requested amount
        // It should emit a {Transfer} event
        uint256 bufferCap = 10_000 * TOKEN_1;
        uint256 rps = (bufferCap / 2) / DAY;
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: bridge,
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(bridge);
        xVelo.mint(users.alice, TOKEN_1);

        vm.startPrank(users.alice);
        xVelo.approve(bridge, TOKEN_1);

        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: users.alice, to: address(0), value: TOKEN_1});
        vm.startPrank(bridge);
        xVelo.burn(users.alice, TOKEN_1);

        RateLimitMidPoint memory limit = xVelo.rateLimits(bridge);
        assertEq(xVelo.balanceOf(users.alice), 0);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint);

        // limits remain at midPoint since burn replenishes limits from mint
        assertEq(xVelo.mintingCurrentLimitOf(bridge), limit.midPoint);
        assertEq(xVelo.mintingMaxLimitOf(bridge), bufferCap);
        assertEq(xVelo.burningCurrentLimitOf(bridge), limit.midPoint);
        assertEq(xVelo.burningMaxLimitOf(bridge), bufferCap);
    }
}
