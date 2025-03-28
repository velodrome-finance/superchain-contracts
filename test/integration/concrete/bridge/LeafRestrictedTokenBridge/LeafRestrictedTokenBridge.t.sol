// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract LeafRestrictedTokenBridgeTest is BaseForkFixture {
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

    function test_InitialState() public view {
        assertEq(leafRestrictedTokenBridge.owner(), users.owner);
        assertEq(leafRestrictedTokenBridge.xerc20(), address(leafRestrictedRewardToken));
        assertEq(leafRestrictedTokenBridge.mailbox(), address(leafMailbox));
        assertEq(leafRestrictedTokenBridge.hook(), address(0));
        assertEq(leafRestrictedTokenBridge.voter(), address(leafVoter));
        assertEq(address(leafRestrictedTokenBridge.securityModule()), address(leafIsm));
        assertEq(address(leafRestrictedTokenBridge).balance, 0);

        uint256[] memory chainids = leafRestrictedTokenBridge.chainids();
        assertEq(chainids.length, 0);

        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(leafRestrictedRewardToken)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 3);
        assertEq(leafVoter.whitelistTokenCount(address(leafRestrictedRewardToken)), 1);
    }
}
