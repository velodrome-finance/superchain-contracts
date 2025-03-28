// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RestrictedXERC20.t.sol";

contract MintIntegrationConcreteTest is RestrictedXERC20Test {
    using SafeCast for uint256;

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimitOfCaller() external {
        // It should revert with "RateLimited: rate limit hit"
        vm.prank(address(leafRestrictedTokenBridge));
        vm.expectRevert("RateLimited: rate limit hit");
        leafRestrictedRewardToken.mint(users.alice, TOKEN_1);
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimitOfCaller() external {
        // It mints the requested amount of tokens to the user
        // It decreases the current minting limit for the caller
        // It should emit a {Transfer} event
        uint256 bufferCap = 10_000 * TOKEN_1;
        uint256 rps = (bufferCap / 2) / DAY;
        vm.startPrank(users.owner);
        leafRestrictedRewardToken.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafRestrictedTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(address(leafRestrictedTokenBridge));
        vm.expectEmit(address(leafRestrictedRewardToken));
        emit IERC20.Transfer({from: address(0), to: users.alice, value: TOKEN_1});
        leafRestrictedRewardToken.mint(users.alice, TOKEN_1);

        RateLimitMidPoint memory limit = leafRestrictedRewardToken.rateLimits(address(leafRestrictedTokenBridge));
        assertEq(leafRestrictedRewardToken.balanceOf(users.alice), TOKEN_1);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint - TOKEN_1);

        assertEq(
            leafRestrictedRewardToken.mintingCurrentLimitOf(address(leafRestrictedTokenBridge)),
            limit.midPoint - TOKEN_1
        );
        assertEq(leafRestrictedRewardToken.mintingMaxLimitOf(address(leafRestrictedTokenBridge)), bufferCap);
        assertEq(
            leafRestrictedRewardToken.burningCurrentLimitOf(address(leafRestrictedTokenBridge)),
            limit.midPoint + TOKEN_1
        );
        assertEq(leafRestrictedRewardToken.burningMaxLimitOf(address(leafRestrictedTokenBridge)), bufferCap);
    }

    function testGas_mint() external {
        // Setup bridge with sufficient minting limits
        uint256 bufferCap = 10_000 * TOKEN_1;
        uint256 rps = (bufferCap / 2) / DAY;
        vm.startPrank(users.owner);
        leafRestrictedRewardToken.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafRestrictedTokenBridge),
                bufferCap: bufferCap.toUint112(),
                rateLimitPerSecond: rps.toUint128()
            })
        );

        vm.startPrank(address(leafRestrictedTokenBridge));
        leafRestrictedRewardToken.mint(users.alice, TOKEN_1);
        vm.snapshotGasLastCall("RestrictedXERC20_mint");
    }
}
