// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RestrictedXERC20Test is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();
        vm.selectFork(rootId);
        // whitelist xop on leaf chain
        address restrictedIncentivePool = rootPoolFactory.createPool({
            chainid: leaf,
            tokenA: address(token0),
            tokenB: address(rootRestrictedRewardToken),
            stable: false
        });
        vm.startPrank({msgSender: mockVoter.governor(), txOrigin: users.alice});
        mockVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: address(restrictedIncentivePool)});
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        vm.stopPrank();
    }

    function test_InitialState() public {
        vm.selectFork(rootId);
        assertEq(rootRestrictedRewardToken.name(), "Superchain OP");
        assertEq(rootRestrictedRewardToken.symbol(), "XOP");
        assertEq(rootRestrictedRewardToken.owner(), users.owner);
        assertEq(rootRestrictedRewardToken.lockbox(), address(rootRestrictedRewardLockbox));
        assertEq(rootRestrictedRewardToken.tokenBridge(), address(rootRestrictedTokenBridge));
        assertEq(rootRestrictedRewardToken.TOKEN_BRIDGE_ENTROPY(), XOP_TOKEN_BRIDGE_ENTROPY);

        address[] memory whitelistedAddresses = rootRestrictedRewardToken.whitelist();
        assertEq(whitelistedAddresses.length, 1);
        assertEq(whitelistedAddresses[0], address(rootRestrictedTokenBridge));
        assertEq(rootRestrictedRewardToken.whitelistLength(), 1);

        vm.selectFork(leafId);
        assertEq(leafRestrictedRewardToken.name(), "Superchain OP");
        assertEq(leafRestrictedRewardToken.symbol(), "XOP");
        assertEq(leafRestrictedRewardToken.owner(), users.owner);
        assertEq(leafRestrictedRewardToken.tokenBridge(), address(leafRestrictedTokenBridge));
        assertEq(leafRestrictedRewardToken.TOKEN_BRIDGE_ENTROPY(), XOP_TOKEN_BRIDGE_ENTROPY);

        whitelistedAddresses = leafRestrictedRewardToken.whitelist();
        assertEq(whitelistedAddresses.length, 1);
        assertEq(whitelistedAddresses[0], address(leafRestrictedTokenBridge));
        assertEq(leafRestrictedRewardToken.whitelistLength(), 1);

        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(leafRestrictedRewardToken)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 3);
        assertEq(leafVoter.whitelistTokenCount(address(leafRestrictedRewardToken)), 1);
    }
}
