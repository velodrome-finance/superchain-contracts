// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract MintingCurrentLimitOfUnitConcreteTest is XERC20Test {
    uint256 public constant mintingLimit = 10_000 * TOKEN_1;
    uint256 public constant usedLimit = 6_000 * TOKEN_1;

    function setUp() public override {
        super.setUp();

        vm.prank(users.owner);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: 0});
    }

    function test_WhenCurrentLimitOfBridgeIsEqualToItsMaxLimit() external view {
        (IXERC20.BridgeParameters memory bpm,) = xVelo.bridges(bridge);
        assertEq(bpm.maxLimit, bpm.currentLimit);

        // It should return the max limit
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit);
    }

    modifier whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit() {
        vm.prank(bridge);
        xVelo.mint(bridge, usedLimit);

        (IXERC20.BridgeParameters memory bpm,) = xVelo.bridges(bridge);
        assertNotEq(bpm.maxLimit, bpm.currentLimit);
        _;
    }

    function test_WhenBlockTimestampIsGreaterThanOrEqualToEndOfLastUpdateDuration()
        external
        whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit
    {
        skip(DAY); // Skip duration period for limits to replenish

        // It should return the max limit
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit);
    }

    modifier whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration() {
        (IXERC20.BridgeParameters memory bpm,) = xVelo.bridges(bridge);
        uint256 endOfLastUpdate = bpm.timestamp + DAY;
        assertLt(block.timestamp, endOfLastUpdate);
        _;
    }

    function test_WhenCalculatedLimitIsGreaterThanMaxLimit()
        external
        whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit
        whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration
    {
        (IXERC20.BridgeParameters memory bpm,) = xVelo.bridges(bridge);
        // Calculate seconds required to vest the limit such that `calculatedLimit > bpm.maxLimit`
        uint256 timeToSkip = (usedLimit / bpm.ratePerSecond) + 1;
        skip(timeToSkip);

        uint256 timePassed = block.timestamp - bpm.timestamp;
        uint256 calculatedLimit = bpm.currentLimit + (timePassed * bpm.ratePerSecond);
        assertGt(calculatedLimit, bpm.maxLimit);

        // It should return the max limit
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit);
    }

    function test_WhenCalculatedLimitIsSmallerThanOrEqualToMaxLimit()
        external
        whenCurrentLimitOfBridgeIsDifferentFromItsMaxLimit
        whenBlockTimestampIsSmallerThanEndOfLastUpdateDuration
    {
        (IXERC20.BridgeParameters memory bpm,) = xVelo.bridges(bridge);
        // Calculate seconds required to vest the limit such that `calculatedLimit == bpm.maxLimit`
        uint256 maxSkip = usedLimit / bpm.ratePerSecond;
        skip(maxSkip / 2);

        uint256 timePassed = block.timestamp - bpm.timestamp;
        uint256 calculatedLimit = bpm.currentLimit + (timePassed * bpm.ratePerSecond);
        assertLe(calculatedLimit, bpm.maxLimit);

        // It should return the linearly vested calculated limit
        assertEq(xVelo.mintingCurrentLimitOf(bridge), calculatedLimit);
    }
}
