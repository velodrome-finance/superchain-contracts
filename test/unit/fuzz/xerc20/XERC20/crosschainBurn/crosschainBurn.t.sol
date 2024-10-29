// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract CrosschainBurnUnitFuzzTest is XERC20Test {
    using SafeCast for uint256;

    function testFuzz_WhenCallerIsNotSuperchainERC20Bridge(address _user) external {
        // It should revert with {OnlySuperchainERC20Bridge}
        vm.assume(_user != SUPERCHAIN_ERC20_BRIDGE);

        vm.prank(_user);
        vm.expectRevert(ISuperchainERC20.OnlySuperchainERC20Bridge.selector);
        xVelo.crosschainBurn({_from: _user, _amount: TOKEN_1});
    }

    modifier whenCallerIsSuperchainERC20Bridge() {
        _;
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller(
        uint112 _bufferCap,
        uint256 _amountToMint,
        uint256 _amountToBurn
    ) external whenCallerIsSuperchainERC20Bridge {
        // It should revert with "RateLimited: buffer cap overflow"

        _bufferCap = bound(_bufferCap, xVelo.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        uint256 midPoint = _bufferCap / 2;
        uint256 rps = Math.min(midPoint / DAY, xVelo.maxRateLimitPerSecond());

        // require: _amountToBurn > burn limit after mint
        _amountToMint = bound(_amountToMint, 0, midPoint);
        // increment by 2 to account for rounding
        _amountToBurn = bound(_amountToBurn, midPoint + _amountToMint + 2, MAX_TOKENS);

        vm.startPrank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: SUPERCHAIN_ERC20_BRIDGE,
                bufferCap: _bufferCap,
                rateLimitPerSecond: rps.toUint128()
            })
        );

        if (_amountToMint > 0) {
            vm.startPrank(SUPERCHAIN_ERC20_BRIDGE);
            xVelo.crosschainMint({_to: users.alice, _amount: _amountToMint});
        }

        deal(address(xVelo), users.alice, _amountToBurn);
        vm.startPrank(users.alice);
        xVelo.approve(SUPERCHAIN_ERC20_BRIDGE, _amountToBurn);

        vm.startPrank(SUPERCHAIN_ERC20_BRIDGE);
        vm.expectRevert("RateLimited: buffer cap overflow");
        xVelo.crosschainBurn({_from: users.alice, _amount: _amountToBurn});
    }

    function testFuzz_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(
        uint112 _bufferCap,
        uint256 _amountToMint,
        uint256 _amountToBurn
    ) external whenCallerIsSuperchainERC20Bridge {
        // It burns the requested amount of tokens
        // It decreases the current burning limit for the caller
        // It decreases the allowance of the caller by the requested amount
        // It should emit a {Transfer} event
        // It should burn the amount from the user
        // It should emit a {CrosschainBurn} event
        _bufferCap = bound(_bufferCap, xVelo.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        uint256 midPoint = _bufferCap / 2;
        uint256 rps = Math.min(midPoint / DAY, xVelo.maxRateLimitPerSecond());

        // require: _amountToBurn <= burn limit after mint
        _amountToMint = bound(_amountToMint, 0, midPoint);
        _amountToBurn = bound(_amountToBurn, 1, midPoint + _amountToMint);
        vm.startPrank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: SUPERCHAIN_ERC20_BRIDGE,
                bufferCap: _bufferCap,
                rateLimitPerSecond: rps.toUint128()
            })
        );

        if (_amountToMint > 0) {
            vm.startPrank(SUPERCHAIN_ERC20_BRIDGE);
            xVelo.crosschainMint({_to: users.alice, _amount: _amountToMint});
        }

        deal(address(xVelo), users.alice, _amountToBurn);
        vm.startPrank(users.alice);
        xVelo.approve(bridge, _amountToBurn);

        vm.startPrank(users.alice);
        xVelo.approve(SUPERCHAIN_ERC20_BRIDGE, _amountToBurn);

        assertEq(xVelo.balanceOf(users.alice), _amountToBurn);

        vm.startPrank(SUPERCHAIN_ERC20_BRIDGE);
        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: users.alice, to: address(0), value: _amountToBurn});
        vm.expectEmit(address(xVelo));
        emit ICrosschainERC20.CrosschainBurn({from: users.alice, amount: _amountToBurn});
        xVelo.crosschainBurn({_from: users.alice, _amount: _amountToBurn});

        RateLimitMidPoint memory limit = xVelo.rateLimits(SUPERCHAIN_ERC20_BRIDGE);
        assertEq(xVelo.balanceOf(users.alice), 0);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, _bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, _bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint + _amountToBurn - _amountToMint);

        // calculate updated limits based on mint & burn amounts
        uint256 delta = _amountToBurn > _amountToMint ? _amountToBurn - _amountToMint : _amountToMint - _amountToBurn;
        (uint256 mintLimit, uint256 burnLimit) = _amountToBurn > _amountToMint
            ? (limit.midPoint + delta, limit.midPoint - delta)
            : (limit.midPoint - delta, limit.midPoint + delta);

        assertApproxEqAbs(xVelo.mintingCurrentLimitOf(SUPERCHAIN_ERC20_BRIDGE), mintLimit, 1);
        assertEq(xVelo.mintingMaxLimitOf(SUPERCHAIN_ERC20_BRIDGE), _bufferCap);
        assertApproxEqAbs(xVelo.burningCurrentLimitOf(SUPERCHAIN_ERC20_BRIDGE), burnLimit, 1);
        assertEq(xVelo.burningMaxLimitOf(SUPERCHAIN_ERC20_BRIDGE), _bufferCap);
    }
}
