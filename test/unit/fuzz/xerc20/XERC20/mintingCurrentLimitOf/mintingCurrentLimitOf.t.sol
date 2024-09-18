// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract MintingCurrentLimitOfUnitFuzzTest is XERC20Test {
    using SafeCast for uint256;

    uint256 public bufferCap;
    uint256 public usedLimit;
    uint256 public midPoint;
    uint256 public rps;

    modifier whenBufferStoredIsSmallerThanMidpoint(uint112 _bufferCap, uint256 _usedLimit) {
        bufferCap = bound(_bufferCap, xVelo.minBufferCap() + 1, MAX_BUFFER_CAP - 1);
        midPoint = bufferCap / 2;
        rps = Math.min(midPoint / DAY, xVelo.maxRateLimitPerSecond());
        /// @dev `usedLimit` can take a max of (type(uint32).max - 1) seconds to vest
        usedLimit = bound(_usedLimit, 1, Math.min(midPoint, rps * (type(uint32).max - 1)));

        vm.prank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: bridge,
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.prank(bridge);
        xVelo.mint(bridge, usedLimit); // mint to decrease buffer stored
        assertLt(xVelo.rateLimits(bridge).bufferStored, midPoint);
        _;
    }

    function testFuzz_WhenSumOfBufferStoredAndAccruedLimitsIsSmallerThanMidpoint(
        uint112 _bufferCap,
        uint256 _usedLimit,
        uint32 _timeskip
    ) external whenBufferStoredIsSmallerThanMidpoint(_bufferCap, _usedLimit) {
        // It should return sum of buffer stored and accrued limits
        uint256 timeToVestLimit = usedLimit / rps; // calculate time to vest used limit
        timeToVestLimit = timeToVestLimit > 0 ? timeToVestLimit - 1 : timeToVestLimit;
        _timeskip = uint32(bound(_timeskip, 0, timeToVestLimit));
        skip(_timeskip);

        uint256 accruedLimits = _timeskip * rps;
        uint256 currentBufferAmount = xVelo.rateLimits(bridge).bufferStored + accruedLimits;
        assertLt(currentBufferAmount, midPoint);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), currentBufferAmount);
    }

    function testFuzz_WhenSumOfBufferStoredAndAccruedLimitsIsGreaterThanOrEqualToMidpoint(
        uint112 _bufferCap,
        uint256 _usedLimit,
        uint32 _timeskip
    ) external whenBufferStoredIsSmallerThanMidpoint(_bufferCap, _usedLimit) {
        // It should return midpoint
        uint256 timeToVestLimit = usedLimit / rps; // calculate time to vest used limit
        _timeskip = uint32(bound(_timeskip, timeToVestLimit + 1, type(uint32).max));
        skip(_timeskip);

        uint256 accruedLimits = _timeskip * rps;
        assertGe(xVelo.rateLimits(bridge).bufferStored + accruedLimits, midPoint);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), midPoint);
    }

    modifier whenBufferStoredIsGreaterThanMidpoint(uint112 _bufferCap, uint256 _usedLimit) {
        bufferCap = bound(_bufferCap, xVelo.minBufferCap() + 1, MAX_BUFFER_CAP - 1);
        midPoint = bufferCap / 2;
        rps = Math.min(midPoint / DAY, xVelo.maxRateLimitPerSecond());
        /// @dev `usedLimit` can take a max of (type(uint32).max - 1) seconds to vest
        usedLimit = bound(_usedLimit, 1, Math.min(midPoint, rps * (type(uint32).max - 1)));

        vm.prank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: bridge,
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        deal(address(xVelo), bridge, usedLimit);
        vm.prank(bridge);
        xVelo.burn(bridge, usedLimit); // burn to increase buffer stored
        assertGt(xVelo.rateLimits(bridge).bufferStored, midPoint);
        _;
    }

    function testFuzz_WhenAccruedLimitsAreGreaterThanBufferStored(
        uint112 _bufferCap,
        uint256 _usedLimit,
        uint32 _timeskip
    ) external whenBufferStoredIsGreaterThanMidpoint(_bufferCap, _usedLimit) {
        // It should return midpoint
        uint256 timeToVestLimit = xVelo.rateLimits(bridge).bufferStored / rps; // calculate time to vest used limit
        vm.assume(timeToVestLimit < type(uint32).max); // avoid skips longer than type(uint32).max
        _timeskip = uint32(bound(_timeskip, timeToVestLimit + 1, type(uint32).max));
        skip(_timeskip);

        uint256 accruedLimits = _timeskip * rps;
        assertGt(accruedLimits, xVelo.rateLimits(bridge).bufferStored);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), midPoint);
    }

    modifier whenAccruedLimitsAreSmallerThanOrEqualToBufferStored() {
        _;
    }

    function testFuzz_WhenTheDifferenceBetweenBufferStoredAndAccruedLimitsIsSmallerThanMidpoint(
        uint112 _bufferCap,
        uint256 _usedLimit,
        uint32 _timeskip
    )
        external
        whenBufferStoredIsGreaterThanMidpoint(_bufferCap, _usedLimit)
        whenAccruedLimitsAreSmallerThanOrEqualToBufferStored
    {
        // It should return midpoint
        uint256 timeToVestUsedLimit = usedLimit / rps; // calculate time to vest used limit
        uint256 timeToVestBufferStored = (midPoint + usedLimit) / rps; // calculate time to vest buffer stored
        vm.assume(timeToVestBufferStored < type(uint32).max); // avoid skips longer than type(uint32).max
        _timeskip = uint32(bound(_timeskip, timeToVestUsedLimit + 1, timeToVestBufferStored));

        skip(_timeskip);

        uint256 accruedLimits = _timeskip * rps;
        assertLt(xVelo.rateLimits(bridge).bufferStored - accruedLimits, midPoint);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), midPoint);
    }

    function testFuzz_WhenTheDifferenceBetweenBufferStoredAndAccruedLimitsIsGreaterThanOrEqualToMidpoint(
        uint112 _bufferCap,
        uint256 _usedLimit,
        uint32 _timeskip
    )
        external
        whenBufferStoredIsGreaterThanMidpoint(_bufferCap, _usedLimit)
        whenAccruedLimitsAreSmallerThanOrEqualToBufferStored
    {
        // It should return the difference between buffer stored and accrued limits
        uint256 timeToVestLimit = usedLimit / rps; // calculate time to vest used limit
        _timeskip = uint32(bound(_timeskip, 0, timeToVestLimit));
        skip(_timeskip);

        uint256 accruedLimits = _timeskip * rps;
        uint256 currentBufferAmount = xVelo.rateLimits(bridge).bufferStored - accruedLimits;
        assertGe(currentBufferAmount, midPoint);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), currentBufferAmount);
    }
}
