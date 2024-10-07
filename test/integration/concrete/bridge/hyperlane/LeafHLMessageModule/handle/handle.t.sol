// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafHLMessageModule.t.sol";

contract HandleIntegrationConcreteTest is LeafHLMessageModuleTest {
    using stdStorage for StdStorage;

    uint32 public origin;
    bytes32 public sender = TypeCasts.addressToBytes32(users.charlie);

    function setUp() public override {
        super.setUp();

        // Notify rewards contracts
        vm.selectFork({forkId: leafId});
        deal(address(token0), address(leafGauge), TOKEN_1 * 2);
        deal(address(token1), address(leafGauge), TOKEN_1 * 2);
        // Using WETH as Bribe token
        deal(address(weth), address(leafGauge), TOKEN_1);

        vm.startPrank(address(leafGauge));
        token0.approve(address(leafFVR), TOKEN_1);
        token1.approve(address(leafFVR), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token1), TOKEN_1);

        token0.approve(address(leafIVR), TOKEN_1);
        token1.approve(address(leafIVR), TOKEN_1);
        weth.approve(address(leafIVR), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token1), TOKEN_1);
        leafIVR.notifyRewardAmount(address(weth), TOKEN_1);
        vm.stopPrank();

        uint256 amountToBridge = TOKEN_1 * 1000;
        setLimits({_rootBufferCap: amountToBridge * 2, _leafBufferCap: amountToBridge * 2});
    }

    function test_WhenTheCallerIsNotMailbox() external {
        // It reverts with NotMailbox
        vm.prank(users.charlie);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafMessageModule.handle({
            _origin: origin,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, abi.encode(1))
        });
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function test_WhenTheOriginIsNotRoot() external whenTheCallerIsMailbox {
        // It should revert with NotRoot
        vm.expectRevert(IHLHandler.NotRoot.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheOriginIsRoot() {
        origin = 10;
        _;
    }

    function test_WhenTheSenderIsNotModule() external whenTheCallerIsMailbox whenTheOriginIsRoot {
        // It should revert with NotModule
        vm.expectRevert(ILeafHLMessageModule.NotModule.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheSenderIsModule() {
        sender = TypeCasts.addressToBytes32(address(leafMessageModule));
        _;
    }

    function test_WhenTheReceivingNonceIsNotTheExpectedNonce()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It should revert with InvalidNonce
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), uint256(999), address(leafGauge), amount, tokenId);

        vm.expectRevert(ILeafHLMessageModule.InvalidNonce.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
    }

    modifier whenTheReceivingNonceIsTheExpectedNonce() {
        _;
    }

    function test_WhenTheCommandIsDeposit()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
        whenTheReceivingNonceIsTheExpectedNonce
    {
        // It decodes the gauge address from the message
        // It calls deposit on the fee rewards contract corresponding to the gauge with the payload
        // It calls deposit on the incentive rewards contract corresponding to the gauge with the payload
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint256(1_000));

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
        assertEq(leafMessageModule.receivingNonce(), 1_001);
    }

    function test_WhenTheCommandIsWithdraw()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
        whenTheReceivingNonceIsTheExpectedNonce
    {
        // It decodes the gauge address from the message
        // It calls withdraw on the fee rewards contract corresponding to the gauge with the payload
        // It calls withdraw on the incentive rewards contract corresponding to the gauge with the payload
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint256(1_000));

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);

        message = abi.encodePacked(uint8(Commands.WITHDRAW), address(leafGauge), amount, tokenId, uint256(1_001));

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(leafFVR.totalSupply(), 0);
        assertEq(leafFVR.balanceOf(tokenId), 0);
        assertEq(leafIVR.totalSupply(), 0);
        assertEq(leafIVR.balanceOf(tokenId), 0);
        assertEq(leafMessageModule.receivingNonce(), 1_002);
    }

    function test_WhenTheCommandIsGetIncentives()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It decodes the gauge address from the message
        // It calls get reward on the incentive rewards contract corresponding to the gauge with the payload
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint256 tokenId = 1;
        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafIVR._deposit({amount: TOKEN_1, tokenId: tokenId});
        vm.stopPrank();

        skipToNextEpoch(1);

        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_INCENTIVES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.alice), 0);

        vm.startPrank(address(leafMailbox));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
        assertEq(weth.balanceOf(users.alice), TOKEN_1);
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    function test_WhenTheCommandIsGetFees() external whenTheCallerIsMailbox whenTheOriginIsRoot whenTheSenderIsModule {
        // It decodes the gauge address from the message
        // It calls get reward on the fee rewards contract corresponding to the gauge with the payload
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint256 tokenId = 1;
        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({amount: TOKEN_1, tokenId: tokenId});
        vm.stopPrank();

        skipToNextEpoch(1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_FEES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);

        vm.startPrank(address(leafMailbox));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    modifier whenTheCommandIsCreateGauge() {
        _;
    }

    function test_WhenThereIsNoPoolForNewGauge()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
        whenTheCommandIsCreateGauge
    {
        // It decodes the pool configuration from the message
        // It calls createPool on pool factory with decoded config
        // It calls createGauge on gauge factory for new pool
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        address pool = Clones.predictDeterministicAddress({
            deployer: address(leafPoolFactory),
            implementation: leafPoolFactory.implementation(),
            salt: keccak256(abi.encodePacked(address(token0), address(token1), true))
        });
        assertFalse(leafPoolFactory.isPool(pool));

        uint24 _poolParam = 1;
        bytes memory message = abi.encodePacked(
            uint8(Commands.CREATE_GAUGE),
            address(leafPoolFactory),
            address(leafVotingRewardsFactory),
            address(leafGaugeFactory),
            address(token0),
            address(token1),
            _poolParam
        );

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertTrue(leafPoolFactory.isPool(pool));
        leafGauge = LeafGauge(leafVoter.gauges(pool));

        assertEq(leafGauge.stakingToken(), pool);
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    function test_WhenThereIsAPoolForNewGauge()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
        whenTheCommandIsCreateGauge
    {
        // It decodes the pool configuration from the message
        // It calls createGauge on gauge factory for pool with given config
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint24 _poolParam = 1;
        leafPool = Pool(leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), fee: _poolParam}));

        bytes memory message = abi.encodePacked(
            uint8(Commands.CREATE_GAUGE),
            address(leafPoolFactory),
            address(leafVotingRewardsFactory),
            address(leafGaugeFactory),
            address(token0),
            address(token1),
            _poolParam
        );

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        leafGauge = LeafGauge(leafVoter.gauges(address(leafPool)));

        assertEq(leafGauge.stakingToken(), address(leafPool));
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    function test_WhenTheCommandIsNotify() external whenTheCallerIsMailbox whenTheOriginIsRoot whenTheSenderIsModule {
        // It decodes the gauge address and the amount from the message
        // It calls mint on the bridge
        // It approves the gauge to spend amount of xerc20
        // It calls notify reward amount on the decoded gauge
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint256 amount = TOKEN_1 * 1000;
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), amount);

        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 0);

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    function test_WhenTheCommandIsNotifyWithoutClaim()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It decodes the gauge address and the amount from the message
        // It calls mint on the bridge
        // It approves the gauge to spend amount of xerc20
        // It calls notify reward without claim on the decoded gauge
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint256 amount = TOKEN_1 * 1000;
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY_WITHOUT_CLAIM), address(leafGauge), amount);

        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 0);

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(leafXVelo.balanceOf(address(leafMessageModule)), 0);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
        assertEq(leafGauge.rewardPerTokenStored(), 0);
        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(rootStartTime), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    function test_WhenTheCommandIsKillGauge()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It decodes the gauge address
        // It calls mint on the bridge
        // It calls killGauge on voter
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        bytes memory message = abi.encodePacked(uint8(Commands.KILL_GAUGE), address(leafGauge));
        vm.expectEmit(address(leafMessageModule));

        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertFalse(leafVoter.isAlive(address(leafGauge)));
        // because of bribePool token0 is still whitelisted
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertFalse(leafVoter.isWhitelistedToken(address(token1)));
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 1);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), 0);
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    function test_WhenTheCommandIsReviveGauge()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It decodes the gauge address
        // It calls mint on the bridge
        // It calls reviveGauge on voter
        // It emits the {ReceivedMessage} event

        // kill gauge by hand
        vm.stopPrank();
        vm.prank(address(leafMessageModule));
        leafVoter.killGauge(address(leafGauge));
        vm.startPrank(address(leafMailbox));

        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        bytes memory message = abi.encodePacked(uint8(Commands.REVIVE_GAUGE), address(leafGauge));
        vm.expectEmit(address(leafMessageModule));

        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertTrue(leafVoter.isAlive(address(leafGauge)));
        assertTrue(leafVoter.isWhitelistedToken(address(token0)));
        assertTrue(leafVoter.isWhitelistedToken(address(token1)));
        // because of bribePool token0 whitelistTokenCount is 2
        assertEq(leafVoter.whitelistTokenCount(address(token0)), 2);
        assertEq(leafVoter.whitelistTokenCount(address(token1)), 1);
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    function test_WhenTheCommandIsInvalid() external whenTheCallerIsMailbox whenTheOriginIsRoot whenTheSenderIsModule {
        // It reverts with {InvalidCommand}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory message = abi.encodePacked(type(uint8).max, address(leafGauge), amount, tokenId);

        vm.expectRevert(ILeafHLMessageModule.InvalidCommand.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
    }
}
