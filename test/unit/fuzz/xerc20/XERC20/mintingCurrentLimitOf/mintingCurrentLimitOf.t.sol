// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract MintingCurrentLimitOfUnitFuzzTest is XERC20Test {
    uint256 public mintingLimit;
    uint256 public usedLimit;
    uint40 public timeskip;

    function testFuzz_WhenCurrentLimitOfBridgeIsEqualToItsMaxLimit(uint256 _mintingLimit) external {
        mintingLimit = bound(_mintingLimit, 0, type(uint256).max / 2);

        vm.prank(users.owner);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: 0});

        (IXERC20.BridgeParameters memory bpm,) = xVelo.bridges(bridge);
        assertEq(bpm.maxLimit, bpm.currentLimit);

        // It should return the max limit
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit);
    }

    modifier whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit(uint256 _mintingLimit, uint256 _usedLimit) {
        // @dev Using `DAY` as minimum limit to avoid having `ratePerSecond == 0`
        mintingLimit = bound(_mintingLimit, DAY, type(uint256).max / 2);
        usedLimit = bound(_usedLimit, 1, mintingLimit - 1);

        vm.prank(users.owner);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: 0});

        vm.prank(bridge);
        xVelo.mint(bridge, usedLimit);

        (IXERC20.BridgeParameters memory bpm,) = xVelo.bridges(bridge);
        assertNotEq(bpm.maxLimit, bpm.currentLimit);
        _;
    }

    function testFuzz_WhenBlockTimestampIsGreaterThanOrEqualToEndOfLastUpdateDuration(
        uint256 _mintingLimit,
        uint256 _usedLimit,
        uint40 _timeskip
    ) external whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit(_mintingLimit, _usedLimit) {
        _timeskip = uint40(bound(_timeskip, DAY, type(uint40).max));
        skip(_timeskip); // Skip duration period, for limits to replenish

        // It should return the max limit
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit);
    }

    modifier whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration() {
        (IXERC20.BridgeParameters memory bpm,) = xVelo.bridges(bridge);
        uint256 endOfLastUpdate = bpm.timestamp + DAY;
        assertLt(block.timestamp, endOfLastUpdate);
        _;
    }

    function testFuzz_WhenCalculatedLimitIsGreaterThanMaxLimit(
        uint256 _mintingLimit,
        uint256 _usedLimit,
        uint40 _timeskip
    )
        external
        whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit(_mintingLimit, _usedLimit)
        whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration
    {
        (IXERC20.BridgeParameters memory bpm,) = xVelo.bridges(bridge);
        // Calculate seconds required to vest the limit such that `calculatedLimit > bpm.maxLimit`
        uint256 secondsToVest = usedLimit / bpm.ratePerSecond + 1;
        vm.assume(secondsToVest < DAY); // Avoid having to skip more than Limit Duration

        // Skip in time to vest Limits
        timeskip = uint40(bound(_timeskip, secondsToVest, DAY - 1));
        skip(timeskip);
        assertLt(block.timestamp, bpm.timestamp + DAY);

        uint256 timePassed = block.timestamp - bpm.timestamp;
        uint256 calculatedLimit = bpm.currentLimit + (timePassed * bpm.ratePerSecond);
        assertGt(calculatedLimit, bpm.maxLimit);

        // It should return the max limit
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit);
    }

    function testFuzz_WhenCalculatedLimitIsSmallerThanOrEqualToMaxLimit(
        uint256 _mintingLimit,
        uint256 _usedLimit,
        uint40 _timeskip
    )
        external
        whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit(_mintingLimit, _usedLimit)
        whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration
    {
        (IXERC20.BridgeParameters memory bpm,) = xVelo.bridges(bridge);
        // Calculate seconds required to vest the limit such that `calculatedLimit == bpm.maxLimit`
        uint256 secondsToVest = usedLimit / bpm.ratePerSecond;
        uint256 maxSkip = secondsToVest < DAY - 1 ? secondsToVest : DAY - 1;

        // Skip in time to vest Limits
        timeskip = uint40(bound(_timeskip, 0, maxSkip));
        skip(timeskip);
        assertLt(block.timestamp, bpm.timestamp + DAY);

        uint256 timePassed = block.timestamp - bpm.timestamp;
        uint256 calculatedLimit = bpm.currentLimit + (timePassed * bpm.ratePerSecond);
        assertLe(calculatedLimit, bpm.maxLimit);

        // It should return the linearly vested calculated limit
        assertEq(xVelo.mintingCurrentLimitOf(bridge), calculatedLimit);
    }
}
