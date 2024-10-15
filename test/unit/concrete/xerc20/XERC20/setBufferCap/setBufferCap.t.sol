// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract SetBufferCapUnitConcreteTest is XERC20Test {
    using SafeCast for uint256;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        xVelo.setBufferCap({_bridge: bridge, _newBufferCap: 0});
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenNewBufferCapIsZero() external whenCallerIsOwner {
        // It should revert with "MintLimits: bufferCap cannot be 0"
        vm.expectRevert("MintLimits: bufferCap cannot be 0");
        xVelo.setBufferCap({_bridge: bridge, _newBufferCap: 0});
    }

    modifier whenNewBufferCapIsNotZero() {
        _;
    }

    function test_WhenThereIsNoRateLimitForGivenBridge() external whenCallerIsOwner whenNewBufferCapIsNotZero {
        // It should revert with "MintLimits: non-existent rate limit"
        vm.expectRevert("MintLimits: non-existent rate limit");
        xVelo.setBufferCap({_bridge: bridge, _newBufferCap: TOKEN_1 * 1000});
    }

    modifier whenThereIsRateLimitForGivenBridge() {
        uint112 bufferCap = (TOKEN_1 * 10_000).toUint112();
        uint128 rps = (bufferCap / DAY).toUint128();
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps})
        );
        _;
    }

    function test_WhenBufferCapIsSmallerThanOrEqualToMinBufferCap()
        external
        whenCallerIsOwner
        whenNewBufferCapIsNotZero
        whenThereIsRateLimitForGivenBridge
    {
        // It should revert with "MintLimits: buffer cap below min"
        uint112 bufferCap = xVelo.minBufferCap();
        vm.expectRevert("MintLimits: buffer cap below min");
        xVelo.setBufferCap({_bridge: bridge, _newBufferCap: bufferCap});
    }

    modifier whenBufferCapIsGreaterThanMinBufferCap() {
        _;
    }

    function test_WhenUpdatedBufferStoredIsGreaterThanNewBufferCap()
        external
        whenCallerIsOwner
        whenNewBufferCapIsNotZero
        whenThereIsRateLimitForGivenBridge
        whenBufferCapIsGreaterThanMinBufferCap
    {
        // It should set last buffer used timestamp to current timestamp
        // It should set new buffer cap
        // It should set bufferStored to new buffer cap
        // It should set midpoint to half of new buffer cap
        // It should emit a {ConfigurationChanged} event
        // It should emit a {BridgeLimitsSet} event
        uint112 bufferCap = xVelo.minBufferCap() + 1;
        uint128 rps = xVelo.rateLimits(bridge).rateLimitPerSecond;
        assertGt(xVelo.rateLimits(bridge).bufferStored, bufferCap);

        vm.startPrank(users.owner);
        vm.expectEmit(address(xVelo));
        emit MintLimits.ConfigurationChanged({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps});
        vm.expectEmit(address(xVelo));
        emit IXERC20.BridgeLimitsSet({_bridge: bridge, _bufferCap: bufferCap});
        xVelo.setBufferCap({_bridge: bridge, _newBufferCap: bufferCap});

        RateLimitMidPoint memory limit = xVelo.rateLimits(bridge);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.bufferCap, bufferCap);
        assertEq(limit.midPoint, bufferCap / 2);
        assertEq(limit.bufferStored, bufferCap);
    }

    function test_WhenUpdatedBufferStoredIsSmallerThanOrEqualToNewBufferCap()
        external
        whenCallerIsOwner
        whenNewBufferCapIsNotZero
        whenThereIsRateLimitForGivenBridge
        whenBufferCapIsGreaterThanMinBufferCap
    {
        // It should set last buffer used timestamp to current timestamp
        // It should update bufferStored
        // It should set new buffer cap
        // It should set midpoint to half of new buffer cap
        // It should emit a {ConfigurationChanged} event
        // It should emit a {BridgeLimitsSet} event
        uint112 oldBufferCap = xVelo.rateLimits(bridge).bufferCap;
        uint128 rps = xVelo.rateLimits(bridge).rateLimitPerSecond;
        uint112 bufferCap = (TOKEN_1 * 20_000).toUint112();

        // mint to decrease buffer stored
        vm.startPrank(bridge);
        xVelo.mint(bridge, oldBufferCap / 2);
        assertEq(xVelo.rateLimits(bridge).bufferStored, 0);

        skip(DAY); // skip to vest bufferStored

        vm.startPrank(users.owner);
        vm.expectEmit(address(xVelo));
        emit MintLimits.ConfigurationChanged({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps});
        vm.expectEmit(address(xVelo));
        emit IXERC20.BridgeLimitsSet({_bridge: bridge, _bufferCap: bufferCap});
        xVelo.setBufferCap({_bridge: bridge, _newBufferCap: bufferCap});

        RateLimitMidPoint memory limit = xVelo.rateLimits(bridge);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.bufferCap, bufferCap);
        assertEq(limit.midPoint, bufferCap / 2);
        assertEq(limit.bufferStored, oldBufferCap / 2);
    }

    function testGas_setBufferCap()
        external
        whenCallerIsOwner
        whenNewBufferCapIsNotZero
        whenThereIsRateLimitForGivenBridge
        whenBufferCapIsGreaterThanMinBufferCap
    {
        uint112 bufferCap = xVelo.minBufferCap() + 1;

        vm.startPrank(users.owner);
        xVelo.setBufferCap({_bridge: bridge, _newBufferCap: bufferCap});
        snapLastCall("XERC20_setBufferCap");
    }
}
