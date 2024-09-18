// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract MintingCurrentLimitOfUnitConcreteTest is XERC20Test {
    using SafeCast for uint256;

    uint256 public constant bufferCap = 20_000 * TOKEN_1;
    uint256 public constant usedLimit = 6_000 * TOKEN_1;
    uint256 public constant midPoint = bufferCap / 2;
    /// @dev limits replenish in a day
    uint256 public constant rps = midPoint / DAY;

    function setUp() public override {
        super.setUp();

        vm.prank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: bridge,
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );
    }

    modifier whenBufferStoredIsSmallerThanMidpoint() {
        vm.prank(bridge);
        xVelo.mint(bridge, usedLimit); // mint to decrease buffer stored
        assertLt(xVelo.rateLimits(bridge).bufferStored, midPoint);
        _;
    }

    function test_WhenSumOfBufferStoredAndAccruedLimitsIsSmallerThanMidpoint()
        external
        whenBufferStoredIsSmallerThanMidpoint
    {
        // It should return sum of buffer stored and accrued limits
        uint256 timeskip = DAY / 2;
        skip(timeskip);

        uint256 accruedLimits = timeskip * rps;
        uint256 currentBufferAmount = xVelo.rateLimits(bridge).bufferStored + accruedLimits;
        assertLt(currentBufferAmount, midPoint);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), currentBufferAmount);
    }

    function test_WhenSumOfBufferStoredAndAccruedLimitsIsGreaterThanOrEqualToMidpoint()
        external
        whenBufferStoredIsSmallerThanMidpoint
    {
        // It should return midpoint
        uint256 timeskip = DAY * 2;
        skip(timeskip);

        uint256 accruedLimits = timeskip * rps;
        assertGe(xVelo.rateLimits(bridge).bufferStored + accruedLimits, midPoint);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), midPoint);
    }

    modifier whenBufferStoredIsGreaterThanMidpoint() {
        deal(address(xVelo), bridge, usedLimit);
        vm.prank(bridge);
        xVelo.burn(bridge, usedLimit); // burn to increase buffer stored
        assertGt(xVelo.rateLimits(bridge).bufferStored, midPoint);
        _;
    }

    function test_WhenAccruedLimitsAreGreaterThanBufferStored() external whenBufferStoredIsGreaterThanMidpoint {
        // It should return midpoint
        uint256 timeskip = DAY * 2;
        skip(timeskip);

        uint256 accruedLimits = timeskip * rps;
        assertGt(accruedLimits, xVelo.rateLimits(bridge).bufferStored);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), midPoint);
    }

    modifier whenAccruedLimitsAreSmallerThanOrEqualToBufferStored() {
        _;
    }

    function test_WhenTheDifferenceBetweenBufferStoredAndAccruedLimitsIsSmallerThanMidpoint()
        external
        whenBufferStoredIsGreaterThanMidpoint
        whenAccruedLimitsAreSmallerThanOrEqualToBufferStored
    {
        // It should return midpoint
        uint256 timeskip = DAY * 2 / 3;
        skip(timeskip);

        uint256 accruedLimits = timeskip * rps;
        assertLt(xVelo.rateLimits(bridge).bufferStored - accruedLimits, midPoint);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), midPoint);
    }

    function test_WhenTheDifferenceBetweenBufferStoredAndAccruedLimitsIsGreaterThanOrEqualToMidpoint()
        external
        whenBufferStoredIsGreaterThanMidpoint
        whenAccruedLimitsAreSmallerThanOrEqualToBufferStored
    {
        // It should return the difference between buffer stored and accrued limits
        uint256 timeskip = DAY / 2;
        skip(timeskip);

        uint256 accruedLimits = timeskip * rps;
        uint256 currentBufferAmount = xVelo.rateLimits(bridge).bufferStored - accruedLimits;
        assertGe(currentBufferAmount, midPoint);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), currentBufferAmount);
    }

    function test_WhenBufferStoredIsEqualToMidpoint() external view {
        // It should return buffer stored
        uint256 bufferStored = xVelo.rateLimits(bridge).bufferStored;
        assertEq(bufferStored, midPoint);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), bufferStored);
    }
}
