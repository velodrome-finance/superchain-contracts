// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract MintUnitFuzzTest is XERC20Test {
    using SafeCast for uint256;

    function setUp() public override {
        super.setUp();

        vm.startPrank(users.owner);
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimitOfCaller(
        uint256 _bufferCap,
        uint256 _mintAmount
    ) external {
        // It should revert with "RateLimited: rate limit hit"

        // require: _mintAmount > _bufferCap
        _bufferCap = bound(_bufferCap, xVelo.minBufferCap() + 1, MAX_BUFFER_CAP - 1);
        _mintAmount = bound(_mintAmount, _bufferCap / 2 + 1, MAX_BUFFER_CAP);
        uint256 rps = Math.min((_bufferCap / 2) / DAY, xVelo.maxRateLimitPerSecond());

        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: bridge,
                bufferCap: _bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(bridge);
        vm.expectRevert("RateLimited: rate limit hit");
        xVelo.mint(users.alice, _mintAmount);
    }

    function testFuzz_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimitOfCaller(
        uint256 _bufferCap,
        uint256 _mintAmount
    ) external {
        // It mints the requested amount of tokens to the user
        // It decreases the current minting limit for the caller
        // It should emit a {Transfer} event

        // require: _mintAmount <= _bufferCap
        _bufferCap = bound(_bufferCap, xVelo.minBufferCap() + 1, MAX_BUFFER_CAP);
        _mintAmount = bound(_mintAmount, 1, _bufferCap / 2);
        uint256 rps = Math.min((_bufferCap / 2) / DAY, xVelo.maxRateLimitPerSecond());

        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: bridge,
                bufferCap: _bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(bridge);
        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: address(0), to: users.alice, value: _mintAmount});
        xVelo.mint(users.alice, _mintAmount);

        RateLimitMidPoint memory limit = xVelo.rateLimits(bridge);
        assertEq(xVelo.balanceOf(users.alice), _mintAmount);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, _bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, _bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint - _mintAmount);

        assertEq(xVelo.mintingCurrentLimitOf(bridge), limit.midPoint - _mintAmount);
        assertEq(xVelo.mintingMaxLimitOf(bridge), _bufferCap);
        assertApproxEqAbs(xVelo.burningCurrentLimitOf(bridge), limit.midPoint + _mintAmount, 1);
        assertEq(xVelo.burningMaxLimitOf(bridge), _bufferCap);
    }
}
