// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootRestrictedTokenBridgeTest is BaseForkFixture {
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
        vm.selectFork(rootId);
    }

    function test_InitialState() public view {
        assertEq(address(rootRestrictedTokenBridge.lockbox()), address(rootRestrictedRewardLockbox));
        assertEq(address(rootRestrictedTokenBridge.erc20()), address(rootIncentiveToken));
        assertEq(rootRestrictedTokenBridge.module(), address(rootMessageModule));
        assertEq(rootRestrictedTokenBridge.owner(), users.owner);
        assertEq(rootRestrictedTokenBridge.xerc20(), address(rootRestrictedRewardToken));
        assertEq(rootRestrictedTokenBridge.mailbox(), address(rootMailbox));
        assertEq(rootRestrictedTokenBridge.hook(), address(0));
        assertEq(address(rootRestrictedTokenBridge.securityModule()), address(rootIsm));
        assertEq(address(rootRestrictedTokenBridge).balance, 0);
        assertEq(rootRestrictedTokenBridge.voter(), address(mockVoter));
        assertEq(rootRestrictedTokenBridge.BASE_CHAIN_ID(), 8453);

        uint256[] memory chainids = rootRestrictedTokenBridge.chainids();
        assertEq(chainids.length, 0);
    }
}
