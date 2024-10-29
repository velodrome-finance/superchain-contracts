// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract CrosschainMintUnitConcreteTest is XERC20Test {
    using SafeCast for uint256;

    function test_WhenCallerIsNotSuperchainERC20Bridge() external {
        // It should revert with {OnlySuperchainERC20Bridge}
        vm.prank(users.charlie);
        vm.expectRevert(ISuperchainERC20.OnlySuperchainERC20Bridge.selector);
        xVelo.crosschainMint({_to: users.charlie, _amount: TOKEN_1});
    }

    modifier whenCallerIsSuperchainERC20Bridge() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimitOfCaller()
        external
        whenCallerIsSuperchainERC20Bridge
    {
        // It should revert with "RateLimited: rate limit hit"
        vm.prank(SUPERCHAIN_ERC20_BRIDGE);
        vm.expectRevert("RateLimited: rate limit hit");
        xVelo.crosschainMint({_to: users.alice, _amount: TOKEN_1});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimitOfCaller()
        external
        whenCallerIsSuperchainERC20Bridge
    {
        // It mints the requested amount of tokens to the user
        // It decreases the current minting limit for the caller
        // It should emit a {Transfer} event
        // It should mint the amount to the user
        // It should emit a {CrosschainMint} event
        uint256 mintAmount = TOKEN_1;
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
        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: address(0), to: users.alice, value: mintAmount});
        vm.expectEmit(address(xVelo));
        emit ICrosschainERC20.CrosschainMint({to: users.alice, amount: mintAmount});
        xVelo.crosschainMint({_to: users.alice, _amount: mintAmount});

        RateLimitMidPoint memory limit = xVelo.rateLimits(SUPERCHAIN_ERC20_BRIDGE);
        assertEq(xVelo.balanceOf(users.alice), mintAmount);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint - mintAmount);

        assertEq(xVelo.balanceOf(users.alice), mintAmount);
        assertEq(xVelo.mintingCurrentLimitOf(SUPERCHAIN_ERC20_BRIDGE), limit.midPoint - mintAmount);
        assertEq(xVelo.mintingMaxLimitOf(SUPERCHAIN_ERC20_BRIDGE), bufferCap);
        assertEq(xVelo.burningCurrentLimitOf(SUPERCHAIN_ERC20_BRIDGE), limit.midPoint + mintAmount);
        assertEq(xVelo.burningMaxLimitOf(SUPERCHAIN_ERC20_BRIDGE), bufferCap);
    }
}
