// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract SetRateLimitPerSecondCapUnitConcreteTest is XERC20Test {
    using SafeCast for uint256;

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        xVelo.setRateLimitPerSecond({_bridge: bridge, _newRateLimitPerSecond: 0});
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenNewRatePerSecondIsGreaterThanMaxRatePerSecond() external whenCallerIsOwner {
        // It should revert with "MintLimits: rateLimitPerSecond too high"
        uint128 rps = xVelo.maxRateLimitPerSecond() + 1;
        vm.expectRevert("MintLimits: rateLimitPerSecond too high");
        xVelo.setRateLimitPerSecond({_bridge: bridge, _newRateLimitPerSecond: rps});
    }

    modifier whenNewRatePerSecondIsSmallerThanOrEqualToMaxRatePerSecond() {
        _;
    }

    function test_WhenThereIsNoRateLimitForGivenBridge()
        external
        whenCallerIsOwner
        whenNewRatePerSecondIsSmallerThanOrEqualToMaxRatePerSecond
    {
        // It should revert with "MintLimits: non-existent rate limit"
        uint128 rps = xVelo.maxRateLimitPerSecond();
        vm.expectRevert("MintLimits: non-existent rate limit");
        xVelo.setRateLimitPerSecond({_bridge: bridge, _newRateLimitPerSecond: rps});
    }

    function test_WhenThereIsRateLimitForGivenBridge()
        external
        whenCallerIsOwner
        whenNewRatePerSecondIsSmallerThanOrEqualToMaxRatePerSecond
    {
        // It should set last buffer used timestamp to current timestamp
        // It should update buffer stored
        // It should set new rate limit per second
        // It should emit a {ConfigurationChanged} event
        uint256 mintAmount = TOKEN_1 * 1000;
        uint128 rps = (mintAmount / DAY).toUint112(); // limits should replenish in 1 day after mint
        uint112 bufferCap = (TOKEN_1 * 10_000).toUint112();
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps})
        );

        // mint to decrease buffer stored
        vm.startPrank(bridge);
        xVelo.mint(bridge, mintAmount);
        assertEq(xVelo.rateLimits(bridge).bufferStored, bufferCap / 2 - mintAmount);
        skip(DAY + 1); // skip to vest back buffer stored

        // set a lower rate per second, but buffer stored should have already fully vested
        rps = rps / 2;
        vm.startPrank(users.owner);
        vm.expectEmit(address(xVelo));
        emit MintLimits.ConfigurationChanged({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps});
        xVelo.setRateLimitPerSecond({_bridge: bridge, _newRateLimitPerSecond: rps});

        RateLimitMidPoint memory limit = xVelo.rateLimits(bridge);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.bufferStored, bufferCap / 2);
        assertEq(limit.rateLimitPerSecond, rps);
    }

    function testGas_setRateLimitPerSecond()
        external
        whenCallerIsOwner
        whenNewRatePerSecondIsSmallerThanOrEqualToMaxRatePerSecond
    {
        uint256 mintAmount = TOKEN_1 * 1000;
        uint128 rps = (mintAmount / DAY).toUint112();
        uint112 bufferCap = (TOKEN_1 * 10_000).toUint112();
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({bridge: bridge, bufferCap: bufferCap, rateLimitPerSecond: rps})
        );

        rps = rps / 2;
        vm.startPrank(users.owner);
        xVelo.setRateLimitPerSecond({_bridge: bridge, _newRateLimitPerSecond: rps});
        snapLastCall("XERC20_setRateLimitPerSecond");
    }
}
