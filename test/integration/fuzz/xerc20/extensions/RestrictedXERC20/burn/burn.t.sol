// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RestrictedXERC20.t.sol";

contract BurnIntegrationFuzzTest is RestrictedXERC20Test {
    using SafeCast for uint256;

    function setUp() public override {
        super.setUp();
        vm.selectFork(leafId);
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller(
        uint112 _bufferCap,
        uint256 _amountToMint,
        uint256 _amountToBurn
    ) external {
        // It should revert with "RateLimited: buffer cap overflow"
        _bufferCap = bound(_bufferCap, leafRestrictedRewardToken.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        uint256 midPoint = _bufferCap / 2;
        uint256 rps = Math.min(midPoint / DAY, leafRestrictedRewardToken.maxRateLimitPerSecond());

        // require: _amountToBurn > burn limit after mint
        _amountToMint = bound(_amountToMint, 0, midPoint);
        // increment by 2 to account for rounding
        _amountToBurn = bound(_amountToBurn, midPoint + _amountToMint + 2, MAX_TOKENS);

        vm.startPrank(users.owner);
        leafRestrictedRewardToken.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafRestrictedTokenBridge),
                bufferCap: _bufferCap,
                rateLimitPerSecond: rps.toUint128()
            })
        );

        if (_amountToMint > 0) {
            vm.startPrank(address(leafRestrictedTokenBridge));
            leafRestrictedRewardToken.mint(users.alice, _amountToMint);
        }

        deal(address(leafRestrictedRewardToken), users.alice, _amountToBurn);
        vm.startPrank(users.alice);
        leafRestrictedRewardToken.approve(address(leafRestrictedTokenBridge), _amountToBurn);

        vm.startPrank(address(leafRestrictedTokenBridge));
        vm.expectRevert("RateLimited: buffer cap overflow");
        leafRestrictedRewardToken.burn(users.alice, _amountToBurn);
    }

    function testFuzz_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(
        uint112 _bufferCap,
        uint256 _amountToMint,
        uint256 _amountToBurn
    ) external {
        // It burns the requested amount of tokens
        // It decreases the current burning limit for the caller
        // It decreases the allowance of the caller by the requested amount
        // It should emit a {Transfer} event

        _bufferCap = bound(_bufferCap, leafRestrictedRewardToken.minBufferCap() + 1, MAX_BUFFER_CAP).toUint112();
        uint256 midPoint = _bufferCap / 2;
        uint256 rps = Math.min(midPoint / DAY, leafRestrictedRewardToken.maxRateLimitPerSecond());

        // require: _amountToBurn <= burn limit after mint
        _amountToMint = bound(_amountToMint, 0, midPoint);
        _amountToBurn = bound(_amountToBurn, 1, midPoint + _amountToMint);

        vm.startPrank(users.owner);
        leafRestrictedRewardToken.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafRestrictedTokenBridge),
                bufferCap: _bufferCap,
                rateLimitPerSecond: rps.toUint128()
            })
        );

        if (_amountToMint > 0) {
            vm.startPrank(address(leafRestrictedTokenBridge));
            leafRestrictedRewardToken.mint(users.alice, _amountToMint);
        }

        deal(address(leafRestrictedRewardToken), users.alice, _amountToBurn);
        vm.startPrank(users.alice);
        leafRestrictedRewardToken.approve(address(leafRestrictedTokenBridge), _amountToBurn);

        vm.expectEmit(address(leafRestrictedRewardToken));
        emit IERC20.Transfer({from: users.alice, to: address(0), value: _amountToBurn});
        vm.startPrank(address(leafRestrictedTokenBridge));
        leafRestrictedRewardToken.burn(users.alice, _amountToBurn);

        RateLimitMidPoint memory limit = leafRestrictedRewardToken.rateLimits(address(leafRestrictedTokenBridge));
        assertEq(leafRestrictedRewardToken.balanceOf(users.alice), 0);
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

        assertApproxEqAbs(
            leafRestrictedRewardToken.mintingCurrentLimitOf(address(leafRestrictedTokenBridge)), mintLimit, 1
        );
        assertEq(leafRestrictedRewardToken.mintingMaxLimitOf(address(leafRestrictedTokenBridge)), _bufferCap);
        assertApproxEqAbs(
            leafRestrictedRewardToken.burningCurrentLimitOf(address(leafRestrictedTokenBridge)), burnLimit, 1
        );
        assertEq(leafRestrictedRewardToken.burningMaxLimitOf(address(leafRestrictedTokenBridge)), _bufferCap);
    }
}
