// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract CrosschainMintUnitFuzzTest is XERC20Test {
    using SafeCast for uint256;

    function testFuzz_WhenCallerIsNotSuperchainERC20Bridge(address _user) external {
        // It should revert with {OnlySuperchainERC20Bridge}
        vm.assume(_user != SUPERCHAIN_ERC20_BRIDGE);

        vm.prank(_user);
        vm.expectRevert(ISuperchainERC20.OnlySuperchainERC20Bridge.selector);
        xVelo.crosschainMint({_to: users.charlie, _amount: TOKEN_1});
    }

    modifier whenCallerIsSuperchainERC20Bridge() {
        _;
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimitOfCaller(
        uint256 _bufferCap,
        uint256 _mintAmount
    ) external whenCallerIsSuperchainERC20Bridge {
        // It should revert with "RateLimited: rate limit hit"

        // require: _mintAmount > _bufferCap
        _bufferCap = bound(_bufferCap, xVelo.minBufferCap() + 1, MAX_BUFFER_CAP - 1);
        _mintAmount = bound(_mintAmount, _bufferCap / 2 + 1, MAX_BUFFER_CAP);
        uint256 rps = Math.min((_bufferCap / 2) / DAY, xVelo.maxRateLimitPerSecond());

        vm.startPrank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: SUPERCHAIN_ERC20_BRIDGE,
                bufferCap: _bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(SUPERCHAIN_ERC20_BRIDGE);
        vm.expectRevert("RateLimited: rate limit hit");
        xVelo.crosschainMint({_to: users.alice, _amount: _mintAmount});
    }

    function testFuzz_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimitOfCaller(
        uint256 _bufferCap,
        uint256 _mintAmount
    ) external whenCallerIsSuperchainERC20Bridge {
        // It mints the requested amount of tokens to the user
        // It decreases the current minting limit for the caller
        // It should emit a {Transfer} event
        // It should mint the amount to the user
        // It should emit a {CrosschainMint} event
        // require: _mintAmount <= _bufferCap
        _bufferCap = bound(_bufferCap, xVelo.minBufferCap() + 1, MAX_BUFFER_CAP);
        _mintAmount = bound(_mintAmount, 1, _bufferCap / 2);
        uint256 rps = Math.min((_bufferCap / 2) / DAY, xVelo.maxRateLimitPerSecond());

        vm.startPrank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: SUPERCHAIN_ERC20_BRIDGE,
                bufferCap: _bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(SUPERCHAIN_ERC20_BRIDGE);
        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: address(0), to: users.alice, value: _mintAmount});
        vm.expectEmit(address(xVelo));
        emit ICrosschainERC20.CrosschainMint({to: users.alice, amount: _mintAmount});
        xVelo.crosschainMint({_to: users.alice, _amount: _mintAmount});

        RateLimitMidPoint memory limit = xVelo.rateLimits(SUPERCHAIN_ERC20_BRIDGE);
        assertEq(xVelo.balanceOf(users.alice), _mintAmount);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, _bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, _bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint - _mintAmount);

        assertEq(xVelo.balanceOf(users.alice), _mintAmount);
        assertEq(xVelo.mintingCurrentLimitOf(SUPERCHAIN_ERC20_BRIDGE), limit.midPoint - _mintAmount);
        assertEq(xVelo.mintingMaxLimitOf(SUPERCHAIN_ERC20_BRIDGE), _bufferCap);
        assertApproxEqAbs(xVelo.burningCurrentLimitOf(SUPERCHAIN_ERC20_BRIDGE), limit.midPoint + _mintAmount, 1);
        assertEq(xVelo.burningMaxLimitOf(SUPERCHAIN_ERC20_BRIDGE), _bufferCap);
    }
}
