// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RestrictedXERC20.t.sol";

contract MintIntegrationFuzzTest is RestrictedXERC20Test {
    using SafeCast for uint256;

    function setUp() public override {
        super.setUp();
        vm.selectFork(leafId);
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimitOfCaller(
        uint256 _bufferCap,
        uint256 _mintAmount
    ) external {
        // It should revert with "RateLimited: rate limit hit"

        // require: _mintAmount > _bufferCap
        _bufferCap = bound(_bufferCap, leafRestrictedRewardToken.minBufferCap() + 1, MAX_BUFFER_CAP - 1);
        _mintAmount = bound(_mintAmount, _bufferCap / 2 + 1, MAX_BUFFER_CAP);
        uint256 rps = Math.min((_bufferCap / 2) / DAY, leafRestrictedRewardToken.maxRateLimitPerSecond());

        vm.startPrank(users.owner);
        leafRestrictedRewardToken.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafRestrictedTokenBridge),
                bufferCap: _bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(address(leafRestrictedTokenBridge));
        vm.expectRevert("RateLimited: rate limit hit");
        leafRestrictedRewardToken.mint(users.alice, _mintAmount);
    }

    function testFuzz_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimitOfCaller(
        uint256 _bufferCap,
        uint256 _mintAmount
    ) external {
        // It mints the requested amount of tokens to the user
        // It decreases the current minting limit for the caller
        // It should emit a {Transfer} event

        // require: _mintAmount <= _bufferCap
        _bufferCap = bound(_bufferCap, leafRestrictedRewardToken.minBufferCap() + 1, MAX_BUFFER_CAP);
        _mintAmount = bound(_mintAmount, 1, _bufferCap / 2);
        uint256 rps = Math.min((_bufferCap / 2) / DAY, leafRestrictedRewardToken.maxRateLimitPerSecond());

        vm.startPrank(users.owner);
        leafRestrictedRewardToken.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafRestrictedTokenBridge),
                bufferCap: _bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(address(leafRestrictedTokenBridge));
        vm.expectEmit(address(leafRestrictedRewardToken));
        emit IERC20.Transfer({from: address(0), to: users.alice, value: _mintAmount});
        leafRestrictedRewardToken.mint(users.alice, _mintAmount);

        RateLimitMidPoint memory limit = leafRestrictedRewardToken.rateLimits(address(leafRestrictedTokenBridge));
        assertEq(leafRestrictedRewardToken.balanceOf(users.alice), _mintAmount);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, _bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, _bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint - _mintAmount);

        assertEq(
            leafRestrictedRewardToken.mintingCurrentLimitOf(address(leafRestrictedTokenBridge)),
            limit.midPoint - _mintAmount
        );
        assertEq(leafRestrictedRewardToken.mintingMaxLimitOf(address(leafRestrictedTokenBridge)), _bufferCap);
        assertApproxEqAbs(
            leafRestrictedRewardToken.burningCurrentLimitOf(address(leafRestrictedTokenBridge)),
            limit.midPoint + _mintAmount,
            1
        );
        assertEq(leafRestrictedRewardToken.burningMaxLimitOf(address(leafRestrictedTokenBridge)), _bufferCap);
    }
}
