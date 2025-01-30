// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RestrictedXERC20.t.sol";

contract BurnIntegrationConcreteTest is RestrictedXERC20Test {
    using SafeCast for uint256;

    function setUp() public override {
        super.setUp();
        vm.selectFork(leafId);
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller() external {
        // It should revert with "RateLimited: buffer cap overflow"
        uint112 bufferCap = leafRestrictedRewardToken.minBufferCap() + 1;
        vm.startPrank(users.owner);
        leafRestrictedRewardToken.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bridge: address(leafRestrictedTokenBridge),
                bufferCap: bufferCap,
                rateLimitPerSecond: (bufferCap / DAY).toUint128()
            })
        );

        vm.startPrank(address(leafRestrictedTokenBridge));
        leafRestrictedRewardToken.mint(users.alice, TOKEN_1);
        uint256 burnAmount = bufferCap / 2 + TOKEN_1 + 2; // account for minted tokens

        vm.startPrank(users.alice);
        leafRestrictedRewardToken.approve(address(leafRestrictedTokenBridge), burnAmount);

        vm.startPrank(address(leafRestrictedTokenBridge));
        vm.expectRevert("RateLimited: buffer cap overflow");
        leafRestrictedRewardToken.burn(users.alice, burnAmount);
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() external {
        // It burns the requested amount of tokens
        // It decreases the current burning limit for the caller
        // It decreases the allowance of the caller by the requested amount
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
        leafRestrictedRewardToken.mint(users.alice, TOKEN_1);

        vm.startPrank(users.alice);
        leafRestrictedRewardToken.approve(address(leafRestrictedTokenBridge), TOKEN_1);

        vm.expectEmit(address(leafRestrictedRewardToken));
        emit IERC20.Transfer({from: users.alice, to: address(0), value: TOKEN_1});
        vm.startPrank(address(leafRestrictedTokenBridge));
        leafRestrictedRewardToken.burn(users.alice, TOKEN_1);

        RateLimitMidPoint memory limit = leafRestrictedRewardToken.rateLimits(address(leafRestrictedTokenBridge));
        assertEq(leafRestrictedRewardToken.balanceOf(users.alice), 0);
        assertEq(limit.rateLimitPerSecond, rps);
        assertEq(limit.bufferCap, bufferCap);
        assertEq(limit.lastBufferUsedTime, block.timestamp);
        assertEq(limit.midPoint, bufferCap / 2);
        assertEq(limit.bufferStored, limit.midPoint);

        // limits remain at midPoint since burn replenishes limits from mint
        assertEq(leafRestrictedRewardToken.mintingCurrentLimitOf(address(leafRestrictedTokenBridge)), limit.midPoint);
        assertEq(leafRestrictedRewardToken.mintingMaxLimitOf(address(leafRestrictedTokenBridge)), bufferCap);
        assertEq(leafRestrictedRewardToken.burningCurrentLimitOf(address(leafRestrictedTokenBridge)), limit.midPoint);
        assertEq(leafRestrictedRewardToken.burningMaxLimitOf(address(leafRestrictedTokenBridge)), bufferCap);
    }

    function testGas_burn() external {
        // Setup bridge with sufficient burning limits
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

        // Mint tokens first so we can burn them
        vm.startPrank(address(leafRestrictedTokenBridge));
        leafRestrictedRewardToken.mint(users.alice, TOKEN_1);

        vm.startPrank(users.alice);
        leafRestrictedRewardToken.approve(address(leafRestrictedTokenBridge), TOKEN_1);

        vm.startPrank(address(leafRestrictedTokenBridge));
        leafRestrictedRewardToken.burn(users.alice, TOKEN_1);
        vm.snapshotGasLastCall("RestrictedXERC20_burn");
    }
}
