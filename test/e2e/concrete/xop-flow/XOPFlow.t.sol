// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseE2EForkFixture.sol";

contract XOPFlowE2EConcreteTest is BaseE2EForkFixture {
    function setUp() public virtual override {
        super.setUp();

        skipToNextEpoch({_offset: 0});

        // Create Lock for Alice & Bob
        vm.startPrank({msgSender: users.alice});
        uint256 amount = TOKEN_1 * 100;
        deal({token: address(rootRewardToken), to: users.alice, give: amount});
        rootRewardToken.approve({spender: address(mockEscrow), value: amount});
        aliceLock = mockEscrow.createLock({_value: amount, _lockDuration: MAX_TIME});

        vm.startPrank({msgSender: users.bob});
        amount = TOKEN_1 * 50;
        deal({token: address(rootRewardToken), to: users.bob, give: amount});
        rootRewardToken.approve({spender: address(mockEscrow), value: amount});
        bobLock = mockEscrow.createLock({_value: amount, _lockDuration: MAX_TIME});
        vm.stopPrank();

        vm.selectFork({forkId: leafId});
        leafStartTime = block.timestamp;
        vm.selectFork({forkId: rootId});
        rootStartTime = block.timestamp;
    }

    function test_XOPFlow() public syncForkTimestamps {
        // whitelist restricted token on leaf chain
        vm.startPrank({msgSender: users.owner});
        RootPool restrictedPool = RootPool(
            rootPoolFactory.createPool({
                chainid: leaf,
                tokenA: address(rootRestrictedRewardToken),
                tokenB: address(weth),
                stable: false
            })
        );

        // whitelist alice for gas sponsoring on both bridges
        rootRestrictedTokenBridge.whitelistForSponsorship({_account: users.alice, _state: true});
        rootMessageModule.whitelistForSponsorship({_account: users.alice, _state: true});
        vm.deal({account: address(rootRestrictedTokenBridgeVault), newBalance: MESSAGE_FEE * 100});
        vm.deal({account: address(rootModuleVault), newBalance: MESSAGE_FEE * 100});
        vm.stopPrank();

        vm.startPrank({msgSender: mockVoter.governor(), txOrigin: users.alice});
        RootGauge restrictedGauge =
            RootGauge(mockVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: address(restrictedPool)}));
        vm.stopPrank();

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        Pool leafRestrictedPool = Pool(
            leafPoolFactory.getPool({tokenA: address(leafRestrictedRewardToken), tokenB: address(weth), stable: false})
        );
        LeafGauge leafRestrictedGauge = LeafGauge(leafVoter.gauges(address(leafRestrictedPool)));

        assertEq(address(leafRestrictedGauge), address(restrictedGauge));
        assertTrue(leafVoter.isWhitelistedToken(address(leafRestrictedRewardToken)));
        assertTrue(leafVoter.isWhitelistedToken(address(weth)));
        assertTrue(leafVoter.isAlive(address(leafRestrictedGauge)));
        assertEq(leafVoter.poolForGauge(address(leafRestrictedGauge)), address(leafRestrictedPool));
        assertTrue(leafVoter.isGauge(address(leafRestrictedGauge)));
        assertNotEq(leafVoter.gaugeToFees(address(leafRestrictedGauge)), address(0));
        assertNotEq(leafVoter.gaugeToIncentive(address(leafRestrictedGauge)), address(0));

        vm.selectFork(rootId);
        // register chains for restricted token bridge
        vm.startPrank(users.owner);
        rootRestrictedTokenBridge.registerChain(leaf);
        vm.selectFork(leafId);
        leafRestrictedTokenBridge.registerChain(root);

        // set rate limits for restricted token bridge
        setLimitsRestricted({_rootBufferCap: TOKEN_1 * 1_000_000, _leafBufferCap: TOKEN_1 * 1_000_000});

        vm.selectFork(rootId);
        // user deposits xop into leaf rewards contract
        uint256 bridgeAmount = TOKEN_1 * 100;
        deal({token: address(rootIncentiveToken), to: users.alice, give: bridgeAmount});

        vm.startPrank({msgSender: users.alice});
        rootIncentiveToken.approve({spender: address(rootRestrictedTokenBridge), value: bridgeAmount});

        rootRestrictedTokenBridge.sendToken({_recipient: address(rootGauge), _amount: bridgeAmount, _chainid: leaf});
        vm.stopPrank();

        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();

        assertEq(leafRestrictedRewardToken.balanceOf(address(leafIVR)), bridgeAmount);
        assertTrue(IncentiveVotingReward(address(leafIVR)).isReward(address(leafRestrictedRewardToken)));
        assertEq(
            IncentiveVotingReward(address(leafIVR)).tokenRewardsPerEpoch(
                address(leafRestrictedRewardToken), VelodromeTimeLibrary.epochStart(block.timestamp)
            ),
            bridgeAmount
        );

        // alice and bob vote for the gauge
        vm.selectFork({forkId: rootId});
        address[] memory pools = new address[](1);
        pools[0] = address(rootPool);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        vm.warp({newTimestamp: VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1});

        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        mockVoter.vote(aliceLock, pools, weights);

        _depositGas({_user: users.bob, _amount: MESSAGE_FEE});
        vm.prank({msgSender: users.bob, txOrigin: users.bob});
        mockVoter.vote(bobLock, pools, weights);

        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        leafMailbox.processNextInboundMessage();

        skipToNextEpoch(0);

        checkVotingRewards({
            _tokenId: aliceLock,
            _tokenA: address(leafRestrictedRewardToken),
            _tokenB: address(weth),
            _expectedBalanceA: bridgeAmount * 2 / 3,
            _expectedBalanceB: 0
        });

        checkVotingRewards({
            _tokenId: bobLock,
            _tokenA: address(leafRestrictedRewardToken),
            _tokenB: address(weth),
            _expectedBalanceA: bridgeAmount * 1 / 3,
            _expectedBalanceB: 0
        });

        // bridge alice's tokens back to root
        uint256 aliceBalance = bridgeAmount * 2 / 3;
        vm.selectFork(leafId);
        vm.startPrank(users.alice);
        leafRestrictedRewardToken.approve(address(leafRestrictedTokenBridge), aliceBalance);
        vm.deal(users.alice, MESSAGE_FEE);
        leafRestrictedTokenBridge.sendToken{value: MESSAGE_FEE}(users.alice, aliceBalance, root);
        vm.stopPrank();

        vm.selectFork(rootId);
        rootMailbox.processNextInboundMessage();

        assertEq(rootIncentiveToken.balanceOf(users.alice), aliceBalance);
    }
}
