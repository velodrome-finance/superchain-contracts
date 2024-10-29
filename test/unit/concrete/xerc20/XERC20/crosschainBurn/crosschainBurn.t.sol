// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract CrosschainBurnUnitConcreteTest is XERC20Test {
    using SafeCast for uint256;

    function test_WhenCallerIsNotSuperchainERC20Bridge() external {
        // It should revert with {OnlySuperchainERC20Bridge}
        vm.prank(users.charlie);
        vm.expectRevert(ISuperchainERC20.OnlySuperchainERC20Bridge.selector);
        xVelo.crosschainBurn({_from: users.charlie, _amount: TOKEN_1});
    }

    modifier whenCallerIsSuperchainERC20Bridge() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller()
        external
        whenCallerIsSuperchainERC20Bridge
    {
        // It should revert with "RateLimited: buffer cap overflow"
        uint112 bufferCap = xVelo.minBufferCap() + 1;
        vm.startPrank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: SUPERCHAIN_ERC20_BRIDGE,
                bufferCap: bufferCap,
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        vm.startPrank(SUPERCHAIN_ERC20_BRIDGE);
        xVelo.crosschainMint({_to: users.alice, _amount: TOKEN_1});
        uint256 burnAmount = bufferCap / 2 + TOKEN_1 + 2; // account for minted tokens

        vm.startPrank(users.alice);
        xVelo.approve(SUPERCHAIN_ERC20_BRIDGE, burnAmount);

        vm.startPrank(SUPERCHAIN_ERC20_BRIDGE);
        vm.expectRevert("RateLimited: buffer cap overflow");
        xVelo.crosschainBurn({_from: users.alice, _amount: burnAmount});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller()
        external
        whenCallerIsSuperchainERC20Bridge
    {
        // It burns the requested amount of tokens
        // It decreases the current burning limit for the caller
        // It decreases the allowance of the caller by the requested amount
        // It should emit a {Transfer} event
        // It should burn the amount from the user
        // It should emit a {CrosschainBurn} event
        uint256 burnAmount = TOKEN_1;
        uint256 bufferCap = 10_000 * TOKEN_1;
        uint256 rps = (bufferCap / 2) / DAY;
        vm.startPrank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: SUPERCHAIN_ERC20_BRIDGE,
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(SUPERCHAIN_ERC20_BRIDGE);
        xVelo.crosschainMint({_to: users.alice, _amount: burnAmount});

        vm.startPrank(users.alice);
        xVelo.approve(SUPERCHAIN_ERC20_BRIDGE, burnAmount);

        assertEq(xVelo.balanceOf(users.alice), burnAmount);

        vm.startPrank(SUPERCHAIN_ERC20_BRIDGE);
        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: users.alice, to: address(0), value: burnAmount});
        vm.expectEmit(address(xVelo));
        emit ICrosschainERC20.CrosschainBurn({from: users.alice, amount: burnAmount});
        xVelo.crosschainBurn({_from: users.alice, _amount: burnAmount});

        RateLimitMidPoint memory limit = xVelo.rateLimits(SUPERCHAIN_ERC20_BRIDGE);
        assertEq(xVelo.balanceOf(users.alice), 0);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint);

        // limits remain at midPoint since burn replenishes limits from mint
        assertEq(xVelo.mintingCurrentLimitOf(SUPERCHAIN_ERC20_BRIDGE), limit.midPoint);
        assertEq(xVelo.mintingMaxLimitOf(SUPERCHAIN_ERC20_BRIDGE), bufferCap);
        assertEq(xVelo.burningCurrentLimitOf(SUPERCHAIN_ERC20_BRIDGE), limit.midPoint);
        assertEq(xVelo.burningMaxLimitOf(SUPERCHAIN_ERC20_BRIDGE), bufferCap);
    }
}
