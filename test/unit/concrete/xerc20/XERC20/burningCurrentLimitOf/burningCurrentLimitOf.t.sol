// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract BurningCurrentLimitOfUnitConcreteTest is XERC20Test {
    uint256 public constant mintingLimit = 12_000 * TOKEN_1;
    uint256 public constant burningLimit = 10_000 * TOKEN_1;
    uint256 public constant usedLimit = 6_000 * TOKEN_1;

    function setUp() public override {
        super.setUp();

        vm.prank(users.owner);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: burningLimit, _burningLimit: burningLimit});
    }

    function test_WhenCurrentLimitOfBridgeIsEqualToItsMaxLimit() external view {
        (, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        assertEq(bpb.maxLimit, bpb.currentLimit);

        // It should return the max limit
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
    }

    modifier whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit() {
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

    function test_WhenBlockTimestampIsGreaterThanOrEqualToEndOfLastUpdateDuration()
        external
        whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit
    {
        skip(DAY); // Skip duration period for limits to replenish

        // It should return the max limit
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
    }

    modifier whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration() {
        (, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        uint256 endOfLastUpdate = bpb.timestamp + DAY;
        assertLt(block.timestamp, endOfLastUpdate);
        _;
    }

    function test_WhenCalculatedLimitIsGreaterThanMaxLimit()
        external
        whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit
        whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration
    {
        (, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        // Calculate seconds required to vest the limit such that `calculatedLimit > bpb.maxLimit`
        uint256 timeToSkip = (usedLimit / bpb.ratePerSecond) + 1;
        skip(timeToSkip);

        uint256 timePassed = block.timestamp - bpb.timestamp;
        uint256 calculatedLimit = bpb.currentLimit + (timePassed * bpb.ratePerSecond);
        assertGt(calculatedLimit, bpb.maxLimit);

        // It should return the max limit
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
    }

    function test_WhenCalculatedLimitIsSmallerThanOrEqualToMaxLimit()
        external
        whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit
        whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration
    {
        (, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        // Calculate seconds required to vest the limit such that `calculatedLimit == bpb.maxLimit`
        uint256 maxSkip = usedLimit / bpb.ratePerSecond;
        skip(maxSkip / 2);

        uint256 timePassed = block.timestamp - bpb.timestamp;
        uint256 calculatedLimit = bpb.currentLimit + (timePassed * bpb.ratePerSecond);
        assertLe(calculatedLimit, bpb.maxLimit);

        // It should return the linearly vested calculated limit
        assertEq(xVelo.burningCurrentLimitOf(bridge), calculatedLimit);
    }
}
