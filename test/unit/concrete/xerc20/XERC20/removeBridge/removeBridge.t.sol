// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract RemoveBridgeUnitConcreteTest is XERC20Test {
    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        xVelo.removeBridge(bridge);
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenThereIsNoRateLimitForGivenBridge() external whenCallerIsOwner {
        // It should revert with "MintLimits: cannot remove non-existent rate limit"
        vm.expectRevert("MintLimits: cannot remove non-existent rate limit");
        xVelo.removeBridge(bridge);
    }

    function test_WhenThereIsRateLimitForGivenBridge() external whenCallerIsOwner {
        // It should delete rate limits for the bridge
        // It should emit a {ConfigurationChanged} event
        uint128 rps = xVelo.maxRateLimitPerSecond();
        uint112 bufferCap = xVelo.minBufferCap() + 1;
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps})
        );

        vm.expectEmit(address(xVelo));
        emit MintLimits.ConfigurationChanged({bridge: bridge, bufferCap: 0, rateLimitPerSecond: 0});
        xVelo.removeBridge(bridge);

        RateLimitMidPoint memory limit = xVelo.rateLimits(bridge);
        assertEq(limit.bufferCap, 0);
        assertEq(limit.lastBufferUsedTime, 0);
        assertEq(limit.bufferCap, 0);
        assertEq(limit.bufferStored, 0);
        assertEq(limit.midPoint, 0);
        assertEq(limit.rateLimitPerSecond, 0);
    }

    function testGas_removeBridge() external whenCallerIsOwner {
        uint128 rps = xVelo.maxRateLimitPerSecond();
        uint112 bufferCap = xVelo.minBufferCap() + 1;
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps})
        );

        xVelo.removeBridge(bridge);
        snapLastCall("XERC20_removeBridge");
    }
}
