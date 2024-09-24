// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract SendMessageIntegrationConcreteTest is RootMessageBridgeTest {
    uint256 public command;

    function setUp() public override {
        super.setUp();
        vm.prank(users.owner);
        rootMessageBridge.deregisterChain({_chainid: leaf});

        // use users.alice as tx.origin
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});
    }

    function test_InitialState() public override {
        vm.selectFork({forkId: rootId});
        assertEq(rootMessageBridge.owner(), users.owner);
        assertEq(rootMessageBridge.xerc20(), address(rootXVelo));
        assertEq(rootMessageBridge.voter(), address(mockVoter));
        assertEq(rootMessageBridge.factoryRegistry(), address(mockFactoryRegistry));
        assertEq(rootMessageBridge.weth(), address(weth));
        // chain was deregistered in set up, but module was added in base fork fixture
        uint256[] memory chainids = rootMessageBridge.chainids();
        assertEq(chainids.length, 0);
        address[] memory modules = rootMessageBridge.modules();
        assertEq(modules.length, 1);
        assertEq(modules[0], address(rootMessageModule));
    }

    function test_WhenTheChainIdIsNotRegistered() external {
        // It should revert with {ChainNotRegistered}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(command, abi.encode(address(leafGauge), payload));

        vm.prank(users.charlie);
        vm.expectRevert(ICrossChainRegistry.ChainNotRegistered.selector);
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    modifier whenTheChainIdIsRegistered() {
        vm.prank(users.owner);
        rootMessageBridge.registerChain({_chainid: leaf, _module: address(leafMessageModule)});
        _;
    }

    modifier whenTheCommandIsDeposit() {
        command = Commands.DEPOSIT;
        _;
    }

    function test_WhenTheCallerIsNotAFeeContractRegisteredOnTheVoter()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsDeposit
    {
        // It should revert with {NotAuthorized}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(command, abi.encode(address(leafGauge), payload));

        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, Commands.DEPOSIT));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function test_WhenTheCallerIsAFeeContractRegisteredOnTheVoter()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsDeposit
    {
        // It dispatches the deposit message to the message module
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(command, abi.encode(address(leafGauge), payload));

        vm.prank({msgSender: address(rootFVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});

        assertEq(weth.balanceOf(users.alice), 0);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
    }

    modifier whenTheCommandIsWithdraw() {
        command = Commands.WITHDRAW;
        _;
    }

    function test_WhenTheCallerIsNotAFeeContractRegisteredOnTheVoter_()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsWithdraw
    {
        // It should revert with {NotAuthorized}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));

        vm.prank({msgSender: address(rootFVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
        message = abi.encode(command, abi.encode(address(leafGauge), payload));
        vm.startPrank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, Commands.WITHDRAW));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function test_WhenTheCallerIsAFeeContractRegisteredOnTheVoter_()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsWithdraw
    {
        // It dispatches the withdraw message to the message module
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 2});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE * 2});

        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));

        vm.prank({msgSender: address(rootFVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
        message = abi.encode(command, abi.encode(address(leafGauge), payload));
        vm.prank({msgSender: address(rootFVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});

        assertEq(weth.balanceOf(users.alice), 0);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);

        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), 0);
        assertEq(leafFVR.balanceOf(tokenId), 0);
        assertEq(leafIVR.totalSupply(), 0);
        assertEq(leafIVR.balanceOf(tokenId), 0);
    }

    modifier whenTheCommandIsCreateGauge() {
        command = Commands.CREATE_GAUGE;
        _;
    }

    function test_WhenTheCallerIsNotRootGaugeFactory()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsCreateGauge
    {
        // It should revert with NotAuthorized
        uint24 _poolParam = 1;
        bytes memory payload = abi.encode(
            address(rootVotingRewardsFactory), address(rootGaugeFactory), address(token0), address(token1), _poolParam
        );
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, abi.encode(address(rootPoolFactory), payload));

        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, Commands.CREATE_GAUGE));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function test_WhenTheCallerIsRootGaugeFactory() external whenTheChainIdIsRegistered whenTheCommandIsCreateGauge {
        // It dispatches the create gauge message to the message module
        uint24 _poolParam = 1;
        bytes memory payload = abi.encode(
            address(rootVotingRewardsFactory), address(rootGaugeFactory), address(token0), address(token1), _poolParam
        );
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, abi.encode(address(rootPoolFactory), payload));

        vm.prank({msgSender: address(rootGaugeFactory), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        address pool = Clones.predictDeterministicAddress({
            deployer: address(leafPoolFactory),
            implementation: leafPoolFactory.implementation(),
            salt: keccak256(abi.encodePacked(address(token0), address(token1), true))
        });

        leafGauge = LeafGauge(leafVoter.gauges(pool));
        assertEq(leafGauge.stakingToken(), pool);
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));
        assertEq(leafGauge.gaugeFactory(), address(leafGaugeFactory));
    }

    modifier whenTheCommandIsGetIncentives() {
        command = Commands.GET_INCENTIVES;

        vm.selectFork({forkId: leafId});
        deal(address(token0), address(leafGauge), TOKEN_1);
        deal(address(token1), address(leafGauge), TOKEN_1);
        // Using WETH as Bribe token
        deal(address(weth), address(leafGauge), TOKEN_1);

        // Notify rewards contracts
        vm.startPrank(address(leafGauge));

        token0.approve(address(leafIVR), TOKEN_1);
        token1.approve(address(leafIVR), TOKEN_1);
        weth.approve(address(leafIVR), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token1), TOKEN_1);
        leafIVR.notifyRewardAmount(address(weth), TOKEN_1);
        vm.stopPrank();

        // Deposit into Reward contracts and Skip to next epoch to accrue rewards
        uint256 tokenId = 1;
        bytes memory depositPayload = abi.encode(TOKEN_1, tokenId);
        vm.prank(address(leafMessageModule));
        leafIVR._deposit({_payload: depositPayload});

        skipToNextEpoch(1);

        vm.selectFork({forkId: rootId});
        _;
    }

    function test_WhenTheCallerIsNotAnIncentiveContractRegisteredOnTheVoter()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsGetIncentives
    {
        // It should revert with NotAuthorized
        uint256 tokenId = 1;
        address[] memory tokens = new address[](0);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);
        bytes memory message = abi.encode(command, abi.encode(address(leafGauge), payload));

        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, Commands.GET_INCENTIVES));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function test_WhenTheCallerIsAnIncentiveContractRegisteredOnTheVoter()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsGetIncentives
    {
        // It dispatches the get incentives message to the message module
        uint256 tokenId = 1;
        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);
        bytes memory message = abi.encode(command, abi.encode(address(leafGauge), payload));

        vm.prank({msgSender: address(rootIVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});

        assertEq(weth.balanceOf(users.alice), 0);

        vm.selectFork({forkId: leafId});
        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.alice), 0);

        leafMailbox.processNextInboundMessage();

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
        assertEq(weth.balanceOf(users.alice), TOKEN_1);
    }

    modifier whenTheCommandIsGetFees() {
        command = Commands.GET_FEES;

        vm.selectFork({forkId: leafId});
        deal(address(token0), address(leafGauge), TOKEN_1);
        deal(address(token1), address(leafGauge), TOKEN_1);

        // Notify rewards contracts
        vm.startPrank(address(leafGauge));
        token0.approve(address(leafFVR), TOKEN_1);
        token1.approve(address(leafFVR), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token1), TOKEN_1);
        vm.stopPrank();

        // Deposit into Reward contracts and Skip to next epoch to accrue rewards
        uint256 tokenId = 1;
        bytes memory depositPayload = abi.encode(TOKEN_1, tokenId);
        vm.prank(address(leafMessageModule));
        leafFVR._deposit({_payload: depositPayload});

        skipToNextEpoch(1);

        vm.selectFork({forkId: rootId});
        _;
    }

    function test_WhenTheCallerIsNotAFeesContractRegisteredOnTheVoter()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsGetFees
    {
        // It should revert with NotAuthorized
        uint256 tokenId = 1;
        address[] memory tokens = new address[](0);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);
        bytes memory message = abi.encode(command, abi.encode(address(leafGauge), payload));

        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, Commands.GET_FEES));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function test_WhenTheCallerIsAFeesContractRegisteredOnTheVoter()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsGetFees
    {
        // It dispatches the get fees message to the message module
        uint256 tokenId = 1;
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);
        bytes memory message = abi.encode(command, abi.encode(address(leafGauge), payload));

        vm.prank({msgSender: address(rootFVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});

        assertEq(weth.balanceOf(users.alice), 0);

        vm.selectFork({forkId: leafId});
        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);

        leafMailbox.processNextInboundMessage();

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
    }

    modifier whenTheCommandIsNotify() {
        command = Commands.NOTIFY;
        _;
    }

    function test_WhenTheCallerIsNotAnAliveGauge() external whenTheChainIdIsRegistered whenTheCommandIsNotify {
        // It should revert with NotValidGauge
        uint256 amount = TOKEN_1 * 1000;
        bytes memory payload = abi.encode(address(leafGauge), amount);
        bytes memory message = abi.encode(command, payload);

        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotValidGauge.selector));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function test_WhenTheCallerIsAnAliveGauge() external whenTheChainIdIsRegistered whenTheCommandIsNotify {
        // It dispatches the notify message to the message module
        uint256 amount = TOKEN_1 * 1000;
        deal(address(leafXVelo), address(rootGauge), amount);

        setLimits({_rootBufferCap: amount * 2, _leafBufferCap: amount * 2});

        bytes memory payload = abi.encode(address(leafGauge), amount);
        bytes memory message = abi.encode(command, payload);

        vm.prank(address(rootGauge));
        leafXVelo.approve(address(rootMessageBridge), amount);
        vm.prank({msgSender: address(rootGauge), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});

        assertEq(weth.balanceOf(users.alice), 0);

        vm.selectFork({forkId: leafId});
        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 0);

        leafMailbox.processNextInboundMessage();
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;

        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / timeUntilNext);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), amount / timeUntilNext);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + timeUntilNext);
    }

    modifier whenTheCommandIsNotifyWithoutClaim() {
        command = Commands.NOTIFY_WITHOUT_CLAIM;
        _;
    }

    function test_WhenCallerIsNotAnAliveGauge()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsNotifyWithoutClaim
    {
        // It should revert with NotValidGauge
        uint256 amount = TOKEN_1 * 1000;
        bytes memory payload = abi.encode(address(leafGauge), amount);
        bytes memory message = abi.encode(command, payload);

        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotValidGauge.selector));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function test_WhenCallerIsAnAliveGauge() external whenTheChainIdIsRegistered whenTheCommandIsNotifyWithoutClaim {
        // It dispatches the notify without claim message to the message module
        uint256 amount = TOKEN_1 * 1000;
        deal(address(leafXVelo), address(rootGauge), amount);

        setLimits({_rootBufferCap: amount * 2, _leafBufferCap: amount * 2});

        bytes memory payload = abi.encode(address(leafGauge), amount);
        bytes memory message = abi.encode(command, payload);

        vm.startPrank({msgSender: address(rootGauge), txOrigin: users.alice});
        leafXVelo.approve(address(rootMessageBridge), amount);
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});

        assertEq(weth.balanceOf(users.alice), 0);

        vm.selectFork({forkId: leafId});
        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 0);

        leafMailbox.processNextInboundMessage();
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;

        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / timeUntilNext);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), amount / timeUntilNext);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + timeUntilNext);
    }

    function test_WhenTheCommandIsNotAnyExpectedCommand() external whenTheChainIdIsRegistered {
        // It should revert with {InvalidCommand}
        command = type(uint256).max;

        bytes memory payload = abi.encode(address(token0), address(token1), true);
        bytes memory message = abi.encode(command, payload);

        vm.prank(users.alice);
        vm.expectRevert(IRootMessageBridge.InvalidCommand.selector);
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }
}
