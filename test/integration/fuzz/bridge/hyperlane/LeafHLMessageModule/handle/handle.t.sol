// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafHLMessageModule.t.sol";

contract HandleIntegrationFuzzTest is LeafHLMessageModuleTest {
    using stdStorage for StdStorage;

    uint32 origin;
    bytes32 sender = TypeCasts.addressToBytes32(users.charlie);

    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});

        setLimits({_rootBufferCap: MAX_BUFFER_CAP, _leafBufferCap: MAX_BUFFER_CAP});
    }

    function testFuzz_WhenCallerIsNotMailbox(address _caller) external {
        // It reverts with {NotMailbox}
        vm.assume(_caller != address(leafMailbox));

        vm.prank(_caller);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafMessageModule.handle({
            _origin: origin,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function testFuzz_WhenTheOriginIsNotRoot(uint32 _origin) external whenTheCallerIsMailbox {
        // It should revert with {NotRoot}
        vm.assume(_origin != root);
        vm.expectRevert(IHLHandler.NotRoot.selector);
        leafMessageModule.handle({
            _origin: _origin,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheOriginIsRoot() {
        origin = 10;
        _;
    }

    function testFuzz_WhenTheSenderIsNotModule(address _sender) external whenTheCallerIsMailbox whenTheOriginIsRoot {
        // It should revert with {NotModule}
        vm.assume(_sender != address(leafMessageModule));
        sender = TypeCasts.addressToBytes32(_sender);
        vm.expectRevert(ILeafHLMessageModule.NotModule.selector);
        leafMessageModule.handle({
            _origin: origin,
            _sender: sender,
            _message: abi.encodePacked(users.charlie, uint256(1))
        });
    }

    modifier whenTheSenderIsModule() {
        sender = TypeCasts.addressToBytes32(address(leafMessageModule));
        _;
    }

    function testFuzz_WhenTheReceivingNonceIsNotTheExpectedNonce(uint256 _nonce)
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It should revert with {InvalidNonce}
        vm.assume(_nonce != leafMessageModule.receivingNonce());
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint256(999));

        vm.expectRevert(ILeafHLMessageModule.InvalidNonce.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
    }

    modifier whenTheReceivingNonceIsTheExpectedNonce() {
        _;
    }

    function testFuzz_WhenTheCommandIsDeposit(uint256 amount)
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

    function testFuzz_WhenTheCommandIsWithdraw(uint256 amount)
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

    function testFuzz_WhenTheCommandIsGetIncentives(uint256 _amount)
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
        _amount = bound(_amount, 1, MAX_BUFFER_CAP);

        deal(address(token0), address(leafGauge), _amount);
        deal(address(token1), address(leafGauge), _amount);
        deal(address(weth), address(leafGauge), _amount);
        vm.startPrank(address(leafGauge));
        token0.approve(address(leafIVR), _amount);
        token1.approve(address(leafIVR), _amount);
        weth.approve(address(leafIVR), _amount);
        leafIVR.notifyRewardAmount(address(token0), _amount);
        leafIVR.notifyRewardAmount(address(token1), _amount);
        leafIVR.notifyRewardAmount(address(weth), _amount);
        vm.stopPrank();

        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafIVR._deposit({amount: _amount, tokenId: tokenId});
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

        assertEq(token0.balanceOf(users.alice), _amount);
        assertEq(token1.balanceOf(users.alice), _amount);
        assertEq(weth.balanceOf(users.alice), _amount);
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    function testFuzz_WhenTheCommandIsGetFees(uint256 _amount)
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It decodes the gauge address from the message
        // It calls get reward on the fee rewards contract corresponding to the gauge with the payload
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint256 tokenId = 1;
        _amount = bound(_amount, 1, MAX_BUFFER_CAP);

        deal(address(token0), address(leafGauge), _amount);
        deal(address(token1), address(leafGauge), _amount);
        // Using WETH as Bribe token
        deal(address(weth), address(leafGauge), _amount);
        vm.startPrank(address(leafGauge));
        token0.approve(address(leafFVR), _amount);
        token1.approve(address(leafFVR), _amount);
        leafFVR.notifyRewardAmount(address(token0), _amount);
        leafFVR.notifyRewardAmount(address(token1), _amount);
        vm.stopPrank();

        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({amount: _amount, tokenId: tokenId});
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

        assertEq(token0.balanceOf(users.alice), _amount);
        assertEq(token1.balanceOf(users.alice), _amount);
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    modifier whenTheCommandIsCreateGauge() {
        _;
    }

    function testFuzz_WhenThereIsNoPoolForNewGauge()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
        whenTheCommandIsCreateGauge
    {}

    function testFuzz_WhenThereIsAPoolForNewGauge()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
        whenTheCommandIsCreateGauge
    {}

    function testFuzz_WhenTheCommandIsNotify(uint256 amount)
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It decodes the gauge address and the amount from the message
        // It calls mint on the bridge
        // It approves the gauge to spend amount of xerc20
        // It calls notify reward amount on the decoded gauge
        // It emits the {ReceivedMessage} event
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;

        amount = bound(amount, timeUntilNext, MAX_BUFFER_CAP / 2);
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

    function testFuzz_WhenTheCommandIsNotifyWithoutClaim(uint256 amount)
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

        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;

        amount = bound(amount, timeUntilNext, MAX_BUFFER_CAP / 2);
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
        assertEq(leafGauge.rewardRateByEpoch(leafStartTime), amount / WEEK);
        assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
        assertEq(leafMessageModule.receivingNonce(), 1_000);
    }

    function testFuzz_WhenTheCommandIsKillGauge()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {}

    function testFuzz_WhenTheCommandIsReviveGauge()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {}

    function testFuzz_WhenTheCommandIsInvalid(uint256 amount)
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It reverts with {InvalidCommand}
        uint256 tokenId = 1;
        bytes memory message = abi.encodePacked(type(uint8).max, address(leafGauge), amount, tokenId);

        vm.expectRevert(ILeafHLMessageModule.InvalidCommand.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
    }
}
