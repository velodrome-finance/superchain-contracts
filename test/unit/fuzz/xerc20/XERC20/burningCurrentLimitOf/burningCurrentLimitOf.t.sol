// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract burningCurrentLimitOfUnitFuzzTest is XERC20Test {
    uint256 public mintingLimit;
    uint256 public burningLimit;
    uint256 public usedLimit;
    uint40 public timeskip;

    function testFuzz_WhenCurrentLimitOfBridgeIsEqualToItsMaxLimit(uint256 _burningLimit) external {
        burningLimit = bound(_burningLimit, 0, type(uint256).max / 2);

        vm.prank(users.owner);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: burningLimit});

        (, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        assertEq(bpb.maxLimit, bpb.currentLimit);

        // It should return the max limit
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
    }

    modifier whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit(uint256 _burningLimit, uint256 _usedLimit) {
        // @dev Using `DAY` as minimum limit to avoid having `ratePerSecond == 0`
        burningLimit = bound(_burningLimit, DAY, type(uint256).max / 2);
        usedLimit = bound(_usedLimit, 1, burningLimit - 1);
        mintingLimit = usedLimit;

        vm.prank(users.owner);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: burningLimit});

        vm.prank(bridge);
        xVelo.mint(users.alice, usedLimit);

        vm.prank(users.alice);
        xVelo.approve(bridge, usedLimit);

        vm.prank(bridge);
        xVelo.burn(users.alice, usedLimit);

        (, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        assertNotEq(bpb.maxLimit, bpb.currentLimit);
        _;
    }

    function testFuzz_WhenBlockTimestampIsGreaterThanOrEqualToEndOfLastUpdateDuration(
        uint256 _burningLimit,
        uint256 _usedLimit,
        uint40 _timeskip
    ) external whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit(_burningLimit, _usedLimit) {
        _timeskip = uint40(bound(_timeskip, DAY, type(uint40).max));
        skip(_timeskip); // Skip duration period, for limits to replenish

        // It should return the max limit
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
    }

    modifier whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration() {
        (, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        uint256 endOfLastUpdate = bpb.timestamp + DAY;
        assertLt(block.timestamp, endOfLastUpdate);
        _;
    }

    function testFuzz_WhenCalculatedLimitIsGreaterThanMaxLimit(
        uint256 _burningLimit,
        uint256 _usedLimit,
        uint40 _timeskip
    )
        external
        whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit(_burningLimit, _usedLimit)
        whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration
    {
        (, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        // Calculate seconds required to vest the limit such that `calculatedLimit > bpb.maxLimit`
        uint256 secondsToVest = usedLimit / bpb.ratePerSecond + 1;
        vm.assume(secondsToVest < DAY); // Avoid having to skip more than Limit Duration

        // Skip in time to vest Limits
        timeskip = uint40(bound(_timeskip, secondsToVest, DAY - 1));
        skip(timeskip);
        assertLt(block.timestamp, bpb.timestamp + DAY);

        uint256 timePassed = block.timestamp - bpb.timestamp;
        uint256 calculatedLimit = bpb.currentLimit + (timePassed * bpb.ratePerSecond);
        assertGt(calculatedLimit, bpb.maxLimit);

        // It should return the max limit
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
    }

    function testFuzz_WhenCalculatedLimitIsSmallerThanOrEqualToMaxLimit(
        uint256 _burningLimit,
        uint256 _usedLimit,
        uint40 _timeskip
    )
        external
        whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit(_burningLimit, _usedLimit)
        whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration
    {
        (, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        // Calculate seconds required to vest the limit such that `calculatedLimit == bpb.maxLimit`
        uint256 secondsToVest = usedLimit / bpb.ratePerSecond;
        uint256 maxSkip = secondsToVest < DAY - 1 ? secondsToVest : DAY - 1;

        // Skip in time to vest Limits
        timeskip = uint40(bound(_timeskip, 0, maxSkip));
        skip(timeskip);
        assertLt(block.timestamp, bpb.timestamp + DAY);

        uint256 timePassed = block.timestamp - bpb.timestamp;
        uint256 calculatedLimit = bpb.currentLimit + (timePassed * bpb.ratePerSecond);
        assertLe(calculatedLimit, bpb.maxLimit);

        // It should return the linearly vested calculated limit
        assertEq(xVelo.burningCurrentLimitOf(bridge), calculatedLimit);
    }
}
