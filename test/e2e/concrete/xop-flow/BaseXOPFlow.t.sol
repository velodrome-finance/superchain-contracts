// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IReward as ILegacyReward} from "src/interfaces/external/IReward.sol";

import "test/BaseE2EForkFixture.sol";

contract BaseXOPFlowE2EConcreteTest is BaseE2EForkFixture {
    using stdStorage for StdStorage;

    IVoter public voter;
    IERC20 public rewardToken;

    function setUpPreCommon() public virtual override {
        vm.startPrank(users.owner);
        rootId = vm.createSelectFork({urlOrAlias: "optimism", blockNumber: 123316800});
        weth = IWETH(0x4200000000000000000000000000000000000006);
        rootStartTime = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: rootStartTime});

        leafId = vm.createSelectFork({urlOrAlias: "base", blockNumber: 26063356});
        weth = IWETH(0x4200000000000000000000000000000000000006);
        vm.stopPrank();
    }

    function setUpLeafChain() public virtual override {
        vm.selectFork({forkId: leafId});

        IPoolFactory factory = IPoolFactory(0x420DD381b31aEf6683db6B902084cB0FFECe40Da);
        voter = IVoter(0x16613524e02ad97eDfeF371bC883F2F5d6C480A5);
        mockEscrow = IVotingEscrow(0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4);
        rewardToken = IERC20(0x940181a94A35A4569E4529A3CDfB74e38FD98631);

        vm.startPrank(users.deployer);
        TestERC20 baseToken = new TestERC20("Base Token", "BASE", 18);
        vm.stopPrank();

        leafPool = Pool(factory.createPool(address(rewardToken), address(baseToken), false));

        vm.prank(voter.governor());
        leafGauge = LeafGauge(voter.createGauge(address(factory), address(leafPool)));

        leafIVR = IncentiveVotingReward(voter.gaugeToBribe(address(leafGauge)));
        leafFVR = FeesVotingReward(voter.gaugeToFees(address(leafGauge)));

        vm.startPrank(users.deployer2);
        leafMailbox = new MultichainMockMailbox(leafDomain);
        leafIsm = new TestIsm();
        vm.stopPrank();

        leafRestrictedParams = DeployLeafRestrictedXERC20.RestrictedXERC20DeploymentParams({
            owner: users.owner,
            mailbox: address(leafMailbox),
            ism: address(leafIsm),
            voter: address(voter),
            outputFilename: "base-xop.json"
        });
        deployRestrictedLeaf = new TestDeployRestrictedXERC20Leaf(leafRestrictedParams);
        stdstore.target(address(deployRestrictedLeaf)).sig("deployer()").checked_write(users.deployer);

        deployRestrictedLeaf.run();

        leafRestrictedXFactory = deployRestrictedLeaf.leafRestrictedXFactory();
        leafRestrictedRewardToken = deployRestrictedLeaf.leafRestrictedRewardToken();
        leafRestrictedTokenBridge = deployRestrictedLeaf.leafRestrictedTokenBridge();
    }

    function setUpPostCommon() public virtual override {
        vm.selectFork({forkId: rootId});
        // mock calls to dispatch
        vm.mockCall({
            callee: address(rootMailbox),
            data: abi.encode(bytes4(keccak256("quoteDispatch(uint32,bytes32,bytes,bytes,address)"))),
            returnData: abi.encode(MESSAGE_FEE)
        });

        // fund paymaster vaults for transaction sponsoring
        vm.deal(address(rootModuleVault), MESSAGE_FEE * 1_000);
        vm.deal(address(rootTokenBridgeVault), MESSAGE_FEE * 1_000);

        vm.prank(users.owner);
        rootMessageModule.setDomain({_chainid: leaf, _domain: leafDomain});
        rootMailbox.addRemoteMailbox({_domain: leafDomain, _mailbox: leafMailbox});
        rootMailbox.setDomainForkId({_domain: leafDomain, _forkId: leafId});

        vm.selectFork({forkId: leafId});
        // mock calls to dispatch
        vm.mockCall({
            callee: address(leafMailbox),
            data: abi.encode(bytes4(keccak256("quoteDispatch(uint32,bytes32,bytes,bytes,address)"))),
            returnData: abi.encode(MESSAGE_FEE)
        });
        leafMailbox.addRemoteMailbox({_domain: rootDomain, _mailbox: rootMailbox});
        leafMailbox.setDomainForkId({_domain: rootDomain, _forkId: rootId});
    }

    function setUp() public virtual override {
        leaf = 8453;
        super.setUp();
        skipToNextEpoch({_offset: 0});

        vm.selectFork({forkId: leafId});
        // Create Lock for Alice & Bob
        vm.startPrank({msgSender: users.alice});
        uint256 amount = TOKEN_1 * 10_000_000;
        deal({token: address(rewardToken), to: users.alice, give: amount});
        rewardToken.approve({spender: address(mockEscrow), value: amount});
        aliceLock = mockEscrow.createLock({_value: amount, _lockDuration: MAX_TIME});

        vm.startPrank({msgSender: users.bob});
        amount = TOKEN_1 * 5_000_000;
        deal({token: address(rewardToken), to: users.bob, give: amount});
        rewardToken.approve({spender: address(mockEscrow), value: amount});
        bobLock = mockEscrow.createLock({_value: amount, _lockDuration: MAX_TIME});
        vm.stopPrank();
    }

    function test_BaseXOPFlow() public {
        vm.selectFork({forkId: leafId});
        // whitelist token
        vm.prank({msgSender: voter.governor()});
        IVoter(voter).whitelistToken({_token: address(leafRestrictedRewardToken), _bool: true});

        vm.selectFork({forkId: rootId});
        // register chains for restricted token bridge
        vm.startPrank({msgSender: users.owner});
        rootRestrictedTokenBridge.registerChain({_chainid: leaf});
        vm.selectFork({forkId: leafId});
        leafRestrictedTokenBridge.registerChain({_chainid: root});

        // set rate limits for restricted token bridge
        setLimitsRestricted({_rootBufferCap: TOKEN_1 * 1_000_000, _leafBufferCap: TOKEN_1 * 1_000_000});

        vm.selectFork({forkId: rootId});
        // user deposits xop into leaf rewards contract
        uint256 bridgeAmount = TOKEN_1 * 100;
        deal({token: address(rootIncentiveToken), to: users.alice, give: bridgeAmount});

        vm.startPrank({msgSender: users.alice});
        rootIncentiveToken.approve({spender: address(rootRestrictedTokenBridge), value: bridgeAmount});

        vm.deal({account: users.alice, newBalance: MESSAGE_FEE});
        rootRestrictedTokenBridge.sendToken{value: MESSAGE_FEE}({
            _recipient: address(leafGauge),
            _amount: bridgeAmount,
            _chainid: leaf
        });
        vm.stopPrank();

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafRestrictedRewardToken.balanceOf(address(leafIVR)), bridgeAmount);
        assertTrue(IncentiveVotingReward(address(leafIVR)).isReward(address(leafRestrictedRewardToken)));
        assertEq(
            IncentiveVotingReward(address(leafIVR)).tokenRewardsPerEpoch(
                address(leafRestrictedRewardToken), VelodromeTimeLibrary.epochStart(block.timestamp)
            ),
            bridgeAmount
        );

        // alice and bob vote for the gauge on base
        address[] memory pools = new address[](1);
        pools[0] = address(leafPool);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1_000;

        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        voter.vote({_tokenId: aliceLock, _poolVote: pools, _weights: weights});

        vm.prank({msgSender: users.bob, txOrigin: users.bob});
        voter.vote({_tokenId: bobLock, _poolVote: pools, _weights: weights});

        skipToNextEpoch({_offset: 0});

        address[] memory tokens = new address[](1);
        tokens[0] = address(leafRestrictedRewardToken);

        vm.startPrank({msgSender: users.alice, txOrigin: users.alice});
        ILegacyReward(address(leafIVR)).getReward({_tokenId: aliceLock, _tokens: tokens});
        assertApproxEqAbs(leafRestrictedRewardToken.balanceOf(users.alice), bridgeAmount * 2 / 3, 1e6);
        vm.stopPrank();

        vm.startPrank({msgSender: users.bob, txOrigin: users.bob});
        ILegacyReward(address(leafIVR)).getReward({_tokenId: bobLock, _tokens: tokens});
        assertApproxEqAbs(leafRestrictedRewardToken.balanceOf(users.bob), bridgeAmount * 1 / 3, 1e6);
        vm.stopPrank();

        // verify whitelist contains token bridge and reward contract
        assertEq(IRestrictedXERC20(address(leafRestrictedRewardToken)).whitelistLength(), 2);
        address[] memory whitelist = IRestrictedXERC20(address(leafRestrictedRewardToken)).whitelist();
        assertEq(whitelist[0], address(leafRestrictedTokenBridge));
        assertEq(whitelist[1], address(leafIVR));

        // bridge alice's tokens back to root
        uint256 aliceBalance = bridgeAmount * 2 / 3;
        vm.selectFork({forkId: leafId});
        vm.startPrank({msgSender: users.alice});
        leafRestrictedRewardToken.approve({spender: address(leafRestrictedTokenBridge), value: aliceBalance});
        vm.deal({account: users.alice, newBalance: MESSAGE_FEE});
        leafRestrictedTokenBridge.sendToken{value: MESSAGE_FEE}({
            _recipient: users.alice,
            _amount: aliceBalance,
            _chainid: root
        });
        vm.stopPrank();

        vm.selectFork({forkId: rootId});
        rootMailbox.processNextInboundMessage();

        assertEq(rootIncentiveToken.balanceOf(users.alice), aliceBalance);
    }

    function test_BaseXOPEOAFlow() public {
        vm.selectFork({forkId: leafId});
        // whitelist token
        vm.prank({msgSender: voter.governor()});
        IVoter(voter).whitelistToken({_token: address(leafRestrictedRewardToken), _bool: true});

        vm.selectFork({forkId: rootId});
        // register chains for restricted token bridge
        vm.startPrank({msgSender: users.owner});
        rootRestrictedTokenBridge.registerChain({_chainid: leaf});
        vm.selectFork({forkId: leafId});
        leafRestrictedTokenBridge.registerChain({_chainid: root});

        // set rate limits for restricted token bridge
        setLimitsRestricted({_rootBufferCap: TOKEN_1 * 1_000_000, _leafBufferCap: TOKEN_1 * 1_000_000});

        vm.selectFork({forkId: rootId});
        // whitelist alice for gas sponsoring
        vm.startPrank({msgSender: users.owner});
        rootRestrictedTokenBridge.whitelistForSponsorship({_account: users.alice, _state: true});
        vm.deal({account: address(rootRestrictedTokenBridgeVault), newBalance: MESSAGE_FEE * 100});
        vm.stopPrank();

        // user deposits xop to their EOA on leaf
        uint256 bridgeAmount = TOKEN_1 * 100;
        deal({token: address(rootIncentiveToken), to: users.alice, give: bridgeAmount});

        vm.startPrank({msgSender: users.alice});
        rootIncentiveToken.approve({spender: address(rootRestrictedTokenBridge), value: bridgeAmount});

        rootRestrictedTokenBridge.sendToken({_recipient: users.alice, _amount: bridgeAmount, _chainid: leaf});
        vm.stopPrank();

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        // verify tokens arrived at EOA
        assertEq(leafRestrictedRewardToken.balanceOf(users.alice), bridgeAmount);
        // verify whitelist only contains token bridge
        assertEq(IRestrictedXERC20(address(leafRestrictedRewardToken)).whitelistLength(), 1);
        assertEq(
            IRestrictedXERC20(address(leafRestrictedRewardToken)).whitelist()[0], address(leafRestrictedTokenBridge)
        );

        // bridge tokens back to root
        vm.startPrank({msgSender: users.alice});
        leafRestrictedRewardToken.approve({spender: address(leafRestrictedTokenBridge), value: bridgeAmount});
        vm.deal({account: users.alice, newBalance: MESSAGE_FEE});
        leafRestrictedTokenBridge.sendToken{value: MESSAGE_FEE}({
            _recipient: users.alice,
            _amount: bridgeAmount,
            _chainid: root
        });
        vm.stopPrank();

        vm.selectFork({forkId: rootId});
        rootMailbox.processNextInboundMessage();

        // verify tokens arrived back at root
        assertEq(rootIncentiveToken.balanceOf(users.alice), bridgeAmount);
    }
}
