// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLMessageBridge.t.sol";

contract HandleIntegrationConcreteTest is HLMessageBridgeTest {
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
    }

    function test_WhenTheCallerIsNotMailbox() external {
        // It reverts with NotMailbox
        vm.prank(users.charlie);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
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
        vm.expectRevert(IHLMessageBridge.NotModule.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheSenderIsModule() {
        sender = TypeCasts.addressToBytes32(address(leafMessageModule));
        _;
    }

    function test_WhenTheCommandIsDeposit() external whenTheCallerIsMailbox whenTheOriginIsRoot whenTheSenderIsModule {
        // It decodes the gauge address from the message
        // It calls deposit on the fee rewards contract corresponding to the gauge with the payload
        // It calls deposit on the incentive rewards contract corresponding to the gauge with the payload
        // It emits the {ReceivedMessage} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
    }

    function test_WhenTheCommandIsWithdraw()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It decodes the gauge address from the message
        // It calls withdraw on the fee rewards contract corresponding to the gauge with the payload
        // It calls withdraw on the incentive rewards contract corresponding to the gauge with the payload
        // It emits the {ReceivedMessage} event
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);

        message = abi.encode(Commands.WITHDRAW, abi.encode(address(leafGauge), payload));

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(leafFVR.totalSupply(), 0);
        assertEq(leafFVR.balanceOf(tokenId), 0);
        assertEq(leafIVR.totalSupply(), 0);
        assertEq(leafIVR.balanceOf(tokenId), 0);
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

        // Deposit into Incentives Reward contract and Skip to next epoch to accrue rewards
        uint256 tokenId = 1;
        bytes memory depositPayload = abi.encode(TOKEN_1, tokenId);
        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafIVR._deposit({_payload: depositPayload});
        vm.stopPrank();

        skipToNextEpoch(1);

        address[] memory tokens = new address[](3);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);
        bytes memory message = abi.encode(Commands.GET_INCENTIVES, abi.encode(address(leafGauge), payload));

        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.alice), 0);

        vm.startPrank(address(leafMailbox));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
        assertEq(weth.balanceOf(users.alice), TOKEN_1);
    }

    function test_WhenTheCommandIsGetFees() external whenTheCallerIsMailbox whenTheOriginIsRoot whenTheSenderIsModule {
        // It decodes the gauge address from the message
        // It calls get reward on the fee rewards contract corresponding to the gauge with the payload
        // It emits the {ReceivedMessage} event

        // Deposit into Fees Reward contract and Skip to next epoch to accrue rewards
        uint256 tokenId = 1;
        bytes memory depositPayload = abi.encode(TOKEN_1, tokenId);
        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({_payload: depositPayload});
        vm.stopPrank();

        skipToNextEpoch(1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);
        bytes memory message = abi.encode(Commands.GET_FEES, abi.encode(address(leafGauge), payload));

        assertEq(token0.balanceOf(users.alice), 0);
        assertEq(token1.balanceOf(users.alice), 0);

        vm.startPrank(address(leafMailbox));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(token0.balanceOf(users.alice), TOKEN_1);
        assertEq(token1.balanceOf(users.alice), TOKEN_1);
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
        // It decodes the configuration from the message
        // It calls createPool on pool factory with decoded config
        // It calls createGauge on gauge factory for new pool
        // It emits the {ReceivedMessage} event
        address pool = Clones.predictDeterministicAddress({
            deployer: address(leafPoolFactory),
            implementation: leafPoolFactory.implementation(),
            salt: keccak256(abi.encodePacked(address(token0), address(token1), true))
        });
        assertFalse(leafPoolFactory.isPool(pool));

        bytes memory payload = abi.encode(address(token0), address(token1), true);
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, payload);

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertTrue(leafPoolFactory.isPool(pool));
        leafGauge = LeafGauge(leafVoter.gauges(pool));

        assertEq(leafGauge.stakingToken(), pool);
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafBridge));
        assertEq(leafGauge.gaugeFactory(), address(leafGaugeFactory));
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

        // using stable = true to avoid collision with existing pool
        leafPool = Pool(leafPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: true}));

        bytes memory payload = abi.encode(address(token0), address(token1), true);
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, payload);

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        leafGauge = LeafGauge(leafVoter.gauges(address(leafPool)));

        assertEq(leafGauge.stakingToken(), address(leafPool));
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafBridge));
        assertEq(leafGauge.gaugeFactory(), address(leafGaugeFactory));
    }

    function test_WhenTheCommandIsInvalid() external whenTheCallerIsMailbox whenTheOriginIsRoot whenTheSenderIsModule {
        // It reverts with {InvalidCommand}
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(type(uint256).max, abi.encode(address(leafGauge), payload));

        vm.expectRevert(IHLMessageBridge.InvalidCommand.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
    }
}
