// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract SendMessageIntegrationFuzzTest is RootMessageBridgeTest {
    uint256 public amount = TOKEN_1 * 1000;
    uint256 public command;

    function setUp() public override {
        super.setUp();
        vm.prank(users.owner);
        rootMessageBridge.deregisterChain({_chainid: leaf});

        // use users.alice as tx.origin
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});

        vm.selectFork({forkId: leafId});
        leafStartTime = block.timestamp;
        vm.selectFork({forkId: rootId});
        rootStartTime = block.timestamp;
    }

    function testFuzz_WhenTheChainIdIsNotRegistered(uint256 _chainid) external {
        // It should revert with {ChainNotRegistered}
        uint256 tokenId = 1;
        bytes memory message = abi.encodePacked(uint8(command), address(leafGauge), amount, tokenId);

        vm.prank(users.charlie);
        vm.expectRevert(ICrossChainRegistry.ChainNotRegistered.selector);
        rootMessageBridge.sendMessage({_chainid: _chainid, _message: message});
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

    function testFuzz_WhenTheCallerIsNotAFeeContractRegisteredOnTheVoter(address _caller)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsDeposit
    {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != address(rootFVR));

        uint256 tokenId = 1;
        bytes memory message = abi.encodePacked(uint8(command), address(leafGauge), amount, tokenId);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, Commands.DEPOSIT));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenTheCallerIsAFeeContractRegisteredOnTheVoter(uint256 _amount)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsDeposit
    {
        // It dispatches the deposit message to the message module
        amount = bound(_amount, 1, MAX_TOKENS);
        uint256 tokenId = 1;
        bytes memory message = abi.encodePacked(uint8(command), address(leafGauge), amount, tokenId);

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

    function testFuzz_WhenTheCallerIsNotAFeeContractRegisteredOnTheVoter_(address _caller)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsWithdraw
    {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != address(rootFVR));

        uint256 tokenId = 1;
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId);

        vm.prank({msgSender: address(rootFVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
        message = abi.encodePacked(uint8(command), address(leafGauge), amount, tokenId);
        vm.startPrank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, Commands.WITHDRAW));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenTheCallerIsAFeeContractRegisteredOnTheVoter_(uint256 _amount)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsWithdraw
    {
        // It dispatches the withdraw message to the message module
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 2});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE * 2});

        _amount = bound(_amount, 1, MAX_TOKENS);
        uint256 tokenId = 1;
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), _amount, tokenId);

        vm.prank({msgSender: address(rootFVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
        message = abi.encodePacked(uint8(command), address(leafGauge), _amount, tokenId);
        vm.prank({msgSender: address(rootFVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});

        assertEq(weth.balanceOf(users.alice), 0);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), _amount);
        assertEq(leafFVR.balanceOf(tokenId), _amount);
        assertEq(leafIVR.totalSupply(), _amount);
        assertEq(leafIVR.balanceOf(tokenId), _amount);

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

    function testFuzz_WhenTheCallerIsNotRootGaugeFactory(address _caller)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsCreateGauge
    {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != address(rootGaugeFactory));
        uint24 _poolParam = 1;
        bytes memory message = abi.encodePacked(
            uint8(command),
            address(rootPoolFactory),
            address(rootVotingRewardsFactory),
            address(rootGaugeFactory),
            address(token0),
            address(token1),
            _poolParam
        );

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, Commands.CREATE_GAUGE));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenTheCallerIsRootGaugeFactory()
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsCreateGauge
    {}

    modifier whenTheCommandIsGetIncentives(uint256 _amount) {
        command = Commands.GET_INCENTIVES;
        amount = bound(_amount, 1, MAX_BUFFER_CAP / 2);

        vm.selectFork({forkId: leafId});
        vm.warp(leafStartTime);
        deal(address(token0), address(leafGauge), amount);
        deal(address(token1), address(leafGauge), amount);
        // Using WETH as Bribe token
        deal(address(weth), address(leafGauge), amount);

        // Notify rewards contracts
        vm.startPrank(address(leafGauge));

        token0.approve(address(leafIVR), amount);
        token1.approve(address(leafIVR), amount);
        weth.approve(address(leafIVR), amount);
        leafIVR.notifyRewardAmount(address(token0), amount);
        leafIVR.notifyRewardAmount(address(token1), amount);
        leafIVR.notifyRewardAmount(address(weth), amount);
        vm.stopPrank();

        // Deposit into Reward contracts and Skip to next epoch to accrue rewards
        uint256 tokenId = 1;
        vm.prank(address(leafMessageModule));
        leafIVR._deposit({amount: amount, tokenId: tokenId});
        vm.warp(leafStartTime + WEEK + 1);

        vm.selectFork({forkId: rootId});
        vm.warp(rootStartTime + WEEK + 1);
        _;
    }

    function testFuzz_WhenTheCallerIsNotAnIncentiveContractRegisteredOnTheVoter(address _caller)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsGetIncentives(0)
    {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != address(rootIVR));
        uint256 tokenId = 1;
        address[] memory tokens = new address[](0);
        bytes memory message =
            abi.encodePacked(uint8(command), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, Commands.GET_INCENTIVES));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenTheCallerIsAnIncentiveContractRegisteredOnTheVoter(uint256 _amount)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsGetIncentives(_amount)
    {
        // It dispatches the get incentives message to the message module
        uint256 tokenId = 1;
        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        bytes memory message =
            abi.encodePacked(uint8(command), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens);

        vm.prank({msgSender: address(rootIVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});

        assertEq(weth.balanceOf(users.alice), 0);

        vm.selectFork({forkId: leafId});
        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.alice), 0);

        vm.warp(leafStartTime + WEEK + 1);
        leafMailbox.processNextInboundMessage();

        assertEq(token0.balanceOf(users.alice), amount);
        assertEq(token1.balanceOf(users.alice), amount);
        assertEq(weth.balanceOf(users.alice), amount);
    }

    modifier whenTheCommandIsGetFees(uint256 _amount) {
        command = Commands.GET_FEES;
        amount = bound(_amount, 1, MAX_BUFFER_CAP / 2);

        vm.selectFork({forkId: leafId});
        vm.warp(leafStartTime);
        deal(address(token0), address(leafGauge), amount);
        deal(address(token1), address(leafGauge), amount);

        // Notify rewards contracts
        vm.startPrank(address(leafGauge));
        token0.approve(address(leafFVR), amount);
        token1.approve(address(leafFVR), amount);
        leafFVR.notifyRewardAmount(address(token0), amount);
        leafFVR.notifyRewardAmount(address(token1), amount);
        vm.stopPrank();

        // Deposit into Reward contracts and Skip to next epoch to accrue rewards
        uint256 tokenId = 1;
        vm.prank(address(leafMessageModule));
        leafFVR._deposit({amount: amount, tokenId: tokenId});
        vm.warp(leafStartTime + WEEK + 1);

        skipToNextEpoch(1);

        vm.selectFork({forkId: rootId});
        vm.warp(rootStartTime + WEEK + 1);
        _;
    }

    function testFuzz_WhenTheCallerIsNotAFeesContractRegisteredOnTheVoter(address _caller)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsGetFees(0)
    {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != address(rootFVR));
        uint256 tokenId = 1;
        address[] memory tokens = new address[](0);
        bytes memory message =
            abi.encodePacked(uint8(command), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, Commands.GET_FEES));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenTheCallerIsAFeesContractRegisteredOnTheVoter(uint256 _amount)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsGetFees(_amount)
    {
        // It dispatches the get fees message to the message module
        uint256 tokenId = 1;
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        bytes memory message =
            abi.encodePacked(uint8(command), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens);

        vm.prank({msgSender: address(rootFVR), txOrigin: users.alice});
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});

        assertEq(weth.balanceOf(users.alice), 0);

        vm.selectFork({forkId: leafId});
        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);

        vm.warp(leafStartTime + WEEK + 1);
        leafMailbox.processNextInboundMessage();

        assertEq(token0.balanceOf(users.alice), amount);
        assertEq(token1.balanceOf(users.alice), amount);
    }

    modifier whenTheCommandIsNotify() {
        command = Commands.NOTIFY;
        _;
    }

    function testFuzz_WhenTheCallerIsNotAnAliveGauge(address _caller)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsNotify
    {
        // It should revert with {NotValidGauge}
        vm.assume(mockVoter.isAlive(_caller) == false);
        bytes memory message = abi.encodePacked(uint8(command), address(leafGauge), amount);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotValidGauge.selector));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenTheCallerIsAnAliveGauge(uint256 _amount)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsNotify
    {
        // It dispatches the notify message to the message module
        amount = bound(_amount, WEEK, MAX_BUFFER_CAP / 2);
        deal(address(rootXVelo), address(rootGauge), amount);

        uint256 bufferCap = Math.max(amount * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        bytes memory message = abi.encodePacked(uint8(command), address(leafGauge), amount);

        vm.prank(address(rootGauge));
        rootXVelo.approve(address(rootMessageBridge), amount);
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

    function testFuzz_WhenCallerIsNotAnAliveGauge(address _caller)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsNotifyWithoutClaim
    {
        // It should revert with {NotValidGauge}
        vm.assume(mockVoter.isAlive(_caller) == false);
        bytes memory message = abi.encodePacked(uint8(command), address(leafGauge), amount);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotValidGauge.selector));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenCallerIsAnAliveGauge(uint256 _amount)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsNotifyWithoutClaim
    {
        // It dispatches the notify without claim message to the message module
        amount = bound(_amount, WEEK, MAX_BUFFER_CAP / 2);
        deal(address(rootXVelo), address(rootGauge), amount);

        uint256 bufferCap = Math.max(amount * 2, rootXVelo.minBufferCap() + 1);
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        bytes memory message = abi.encodePacked(uint8(command), address(leafGauge), amount);

        vm.startPrank({msgSender: address(rootGauge), txOrigin: users.alice});
        rootXVelo.approve(address(rootMessageBridge), amount);
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

    modifier whenTheCommandIsKillGauge() {
        command = Commands.KILL_GAUGE;
        _;
    }

    function testFuzz_WhenCallerIsNotEmergencyCouncil(address _caller)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsKillGauge
    {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != mockVoter.emergencyCouncil());
        bytes memory message = abi.encodePacked(uint8(command), address(leafGauge));

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, command));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenCallerIsEmergencyCouncil() external whenTheChainIdIsRegistered whenTheCommandIsKillGauge {}

    modifier whenTheCommandIsReviveGauge() {
        command = Commands.REVIVE_GAUGE;
        _;
    }

    function testFuzz_WhenCallerIsNotEmergencyCouncil_(address _caller)
        external
        whenTheChainIdIsRegistered
        whenTheCommandIsReviveGauge
    {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != mockVoter.emergencyCouncil());
        bytes memory message = abi.encodePacked(uint8(command), address(leafGauge));

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IRootMessageBridge.NotAuthorized.selector, command));
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }

    function testFuzz_WhenCallerIsEmergencyCouncil_() external whenTheChainIdIsRegistered whenTheCommandIsReviveGauge {}

    function testFuzz_WhenTheCommandIsNotAnyExpectedCommand(uint8 _command) external whenTheChainIdIsRegistered {
        // It should revert with {InvalidCommand}
        command = uint8(bound(_command, Commands.REVIVE_GAUGE + 1, type(uint8).max));
        bytes memory message = abi.encodePacked(uint8(command), address(token0), address(token1), true);

        vm.prank(users.alice);
        vm.expectRevert(IRootMessageBridge.InvalidCommand.selector);
        rootMessageBridge.sendMessage({_chainid: leaf, _message: message});
    }
}
