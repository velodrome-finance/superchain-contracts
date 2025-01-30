// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RestrictedXERC20Test is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork(rootId);
        assertEq(rootRestrictedRewardToken.name(), "Superchain OP");
        assertEq(rootRestrictedRewardToken.symbol(), "XOP");
        assertEq(rootRestrictedRewardToken.owner(), users.owner);
        assertEq(rootRestrictedRewardToken.lockbox(), address(rootRestrictedRewardLockbox));
        assertEq(rootRestrictedRewardToken.tokenBridge(), address(rootTokenBridge));
        assertEq(rootRestrictedRewardToken.TOKEN_BRIDGE_ENTROPY(), TOKEN_BRIDGE_ENTROPY_V2);

        address[] memory whitelistedAddresses = rootRestrictedRewardToken.whitelist();
        assertEq(whitelistedAddresses.length, 1);
        assertEq(whitelistedAddresses[0], address(rootTokenBridge));
        assertEq(rootRestrictedRewardToken.whitelistLength(), 1);

        vm.selectFork(leafId);
        assertEq(leafRestrictedRewardToken.name(), "Superchain OP");
        assertEq(leafRestrictedRewardToken.symbol(), "XOP");
        assertEq(leafRestrictedRewardToken.owner(), users.owner);
        assertEq(leafRestrictedRewardToken.tokenBridge(), address(leafTokenBridge));
        assertEq(rootRestrictedRewardToken.TOKEN_BRIDGE_ENTROPY(), TOKEN_BRIDGE_ENTROPY_V2);

        whitelistedAddresses = leafRestrictedRewardToken.whitelist();
        assertEq(whitelistedAddresses.length, 1);
        assertEq(whitelistedAddresses[0], address(leafTokenBridge));
        assertEq(leafRestrictedRewardToken.whitelistLength(), 1);
    }
}
