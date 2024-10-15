// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract AddBridgeUnitConcreteTest is XERC20Test {
    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        xVelo.addBridge(MintLimits.RateLimitMidPointInfo({bridge: address(0), bufferCap: 0, rateLimitPerSecond: 0}));
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenRateLimitPerSecondIsGreaterThanMaxRatePerSecond() external whenCallerIsOwner {
        // It should revert with "MintLimits: rateLimitPerSecond too high"
        uint128 rps = xVelo.maxRateLimitPerSecond() + 1;

        vm.expectRevert("MintLimits: rateLimitPerSecond too high");
        xVelo.addBridge(MintLimits.RateLimitMidPointInfo({bridge: address(0), bufferCap: 0, rateLimitPerSecond: rps}));
    }

    modifier whenRateLimitPerSecondIsSmallerThanOrEqualToMaxRatePerSecond() {
        _;
    }

    function test_WhenBridgeIsAddressZero()
        external
        whenCallerIsOwner
        whenRateLimitPerSecondIsSmallerThanOrEqualToMaxRatePerSecond
    {
        // It should revert with "MintLimits: invalid bridge address"
        uint128 rps = xVelo.maxRateLimitPerSecond();

        vm.expectRevert("MintLimits: invalid bridge address");
        xVelo.addBridge(MintLimits.RateLimitMidPointInfo({bridge: address(0), bufferCap: 0, rateLimitPerSecond: rps}));
    }

    modifier whenBridgeIsNotAddressZero() {
        _;
    }

    function test_WhenThereIsRateLimitForGivenBridge()
        external
        whenCallerIsOwner
        whenRateLimitPerSecondIsSmallerThanOrEqualToMaxRatePerSecond
        whenBridgeIsNotAddressZero
    {
        // It should revert with "MintLimits: rate limit already exists"
        uint128 rps = xVelo.maxRateLimitPerSecond();
        uint112 bufferCap = xVelo.minBufferCap() + 1;
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps})
        );

        vm.expectRevert("MintLimits: rate limit already exists");
        xVelo.addBridge(MintLimits.RateLimitMidPointInfo({bridge: bridge, bufferCap: 0, rateLimitPerSecond: rps}));
    }

    modifier whenThereIsNoRateLimitForGivenBridge() {
        assertEq(xVelo.rateLimits(bridge).bufferCap, 0);
        _;
    }

    function test_WhenBufferCapIsSmallerThanOrEqualToMinBufferCap()
        external
        whenCallerIsOwner
        whenRateLimitPerSecondIsSmallerThanOrEqualToMaxRatePerSecond
        whenBridgeIsNotAddressZero
        whenThereIsNoRateLimitForGivenBridge
    {
        // It should revert with "MintLimits: buffer cap below min"
        uint128 rps = xVelo.maxRateLimitPerSecond();

        vm.expectRevert("MintLimits: buffer cap below min");
        xVelo.addBridge(MintLimits.RateLimitMidPointInfo({bridge: bridge, bufferCap: 0, rateLimitPerSecond: rps}));
    }

    function test_WhenBufferCapIsGreaterThanMinBufferCap()
        external
        whenCallerIsOwner
        whenRateLimitPerSecondIsSmallerThanOrEqualToMaxRatePerSecond
        whenBridgeIsNotAddressZero
        whenThereIsNoRateLimitForGivenBridge
    {
        // It should set a new buffer cap for the bridge
        // It should set last buffer used time to the current timestamp
        // It should set buffer stored to half of buffer cap for the bridge
        // It should set midpoint to half of buffer cap for the bridge
        // It should set a new rate limit per second for the bridge
        // It should emit a {ConfigurationChanged} event
        uint128 rps = xVelo.maxRateLimitPerSecond();
        uint112 bufferCap = xVelo.minBufferCap() + 1;

        vm.expectEmit(address(xVelo));
        emit MintLimits.ConfigurationChanged({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps});
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps})
        );

        RateLimitMidPoint memory limit = xVelo.rateLimits(bridge);
        assertEq(limit.bufferCap, bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.bufferCap, bufferCap);
        assertEq(limit.bufferStored, bufferCap / 2);
        assertEq(limit.midPoint, bufferCap / 2);
        assertEq(limit.rateLimitPerSecond, rps);
    }

    function testGas_addBridge()
        external
        whenCallerIsOwner
        whenRateLimitPerSecondIsSmallerThanOrEqualToMaxRatePerSecond
        whenBridgeIsNotAddressZero
        whenThereIsNoRateLimitForGivenBridge
    {
        uint128 rps = xVelo.maxRateLimitPerSecond();
        uint112 bufferCap = xVelo.minBufferCap() + 1;

        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps})
        );
        snapLastCall("XERC20_addBridge");
    }
}
