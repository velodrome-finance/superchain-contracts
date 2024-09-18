// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract BurnUnitFuzzTest is XERC20Test {
    using SafeCast for uint256;

    function setUp() public override {
        super.setUp();

        vm.startPrank(users.owner);
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller(
        uint112 _bufferCap,
        uint256 _amountToMint,
        uint256 _amountToBurn
    ) external {
        // It should revert with "RateLimited: buffer cap overflow"

        _bufferCap = bound(_bufferCap, xVelo.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        uint256 midPoint = _bufferCap / 2;
        uint256 rps = Math.min(midPoint / DAY, xVelo.maxRateLimitPerSecond());

        // require: _amountToBurn > burn limit after mint
        _amountToMint = bound(_amountToMint, 0, midPoint);
        // increment by 2 to account for rounding
        _amountToBurn = bound(_amountToBurn, midPoint + _amountToMint + 2, MAX_TOKENS);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: bridge,
                bufferCap: _bufferCap,
                rateLimitPerSecond: rps.toUint128()
            })
        );

        if (_amountToMint > 0) {
            vm.startPrank(bridge);
            xVelo.mint(users.alice, _amountToMint);
        }

        deal(address(xVelo), users.alice, _amountToBurn);
        vm.startPrank(users.alice);
        xVelo.approve(bridge, _amountToBurn);

        vm.startPrank(bridge);
        vm.expectRevert("RateLimited: buffer cap overflow");
        xVelo.burn(users.alice, _amountToBurn);
    }

    function testFuzz_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(
        uint112 _bufferCap,
        uint256 _amountToMint,
        uint256 _amountToBurn
    ) external {
        // It burns the requested amount of tokens
        // It decreases the current burning limit for the caller
        // It decreases the allowance of the caller by the requested amount
        // It should emit a {Transfer} event

        _bufferCap = bound(_bufferCap, xVelo.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        uint256 midPoint = _bufferCap / 2;
        uint256 rps = Math.min(midPoint / DAY, xVelo.maxRateLimitPerSecond());

        // require: _amountToBurn <= burn limit after mint
        _amountToMint = bound(_amountToMint, 0, midPoint);
        _amountToBurn = bound(_amountToBurn, 1, midPoint + _amountToMint);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: bridge,
                bufferCap: _bufferCap,
                rateLimitPerSecond: rps.toUint128()
            })
        );

        if (_amountToMint > 0) {
            vm.startPrank(bridge);
            xVelo.mint(users.alice, _amountToMint);
        }

        deal(address(xVelo), users.alice, _amountToBurn);
        vm.startPrank(users.alice);
        xVelo.approve(bridge, _amountToBurn);

        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: users.alice, to: address(0), value: _amountToBurn});
        vm.startPrank(bridge);
        xVelo.burn(users.alice, _amountToBurn);

        RateLimitMidPoint memory limit = xVelo.rateLimits(bridge);
        assertEq(xVelo.balanceOf(users.alice), 0);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, _bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, _bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint + _amountToBurn - _amountToMint);

        // calculate updated limits based on mint & burn amounts
        uint256 delta = _amountToBurn > _amountToMint ? _amountToBurn - _amountToMint : _amountToMint - _amountToBurn;
        (uint256 mintLimit, uint256 burnLimit) = _amountToBurn > _amountToMint
            ? (limit.midPoint + delta, limit.midPoint - delta)
            : (limit.midPoint - delta, limit.midPoint + delta);

        assertApproxEqAbs(xVelo.mintingCurrentLimitOf(bridge), mintLimit, 1);
        assertEq(xVelo.mintingMaxLimitOf(bridge), _bufferCap);
        assertApproxEqAbs(xVelo.burningCurrentLimitOf(bridge), burnLimit, 1);
        assertEq(xVelo.burningMaxLimitOf(bridge), _bufferCap);
    }
}
