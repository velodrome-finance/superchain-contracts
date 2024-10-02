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
        // It reverts with NotMailbox
        vm.assume(_caller != address(leafMailbox));

        vm.prank(_caller);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function testFuzz_WhenTheOriginIsNotRoot(uint32 _origin) external whenTheCallerIsMailbox {
        // It should revert with NotRoot
        vm.assume(_origin != root);
        vm.expectRevert(IHLHandler.NotRoot.selector);
        leafMessageModule.handle({_origin: _origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheOriginIsRoot() {
        origin = 10;
        _;
    }

    function testFuzz_WhenTheSenderIsNotModule(address _sender) external whenTheCallerIsMailbox whenTheOriginIsRoot {
        // It should revert with NotModule
        vm.assume(_sender != address(leafMessageModule));
        sender = TypeCasts.addressToBytes32(_sender);
        vm.expectRevert(ILeafHLMessageModule.NotModule.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
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
        // It should revert with InvalidNonce
        vm.assume(_nonce != leafMessageModule.receivingNonce());
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(999, abi.encode(address(leafGauge), payload)));

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
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(1_000, abi.encode(address(leafGauge), payload)));

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
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(1_000, abi.encode(address(leafGauge), payload)));

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);

        message = abi.encode(Commands.WITHDRAW, abi.encode(1_001, abi.encode(address(leafGauge), payload)));

        vm.expectEmit(address(leafMessageModule));
        emit IHLHandler.ReceivedMessage({_origin: origin, _sender: sender, _value: 0, _message: string(message)});
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});

        assertEq(leafFVR.totalSupply(), 0);
        assertEq(leafFVR.balanceOf(tokenId), 0);
        assertEq(leafIVR.totalSupply(), 0);
        assertEq(leafIVR.balanceOf(tokenId), 0);
        assertEq(leafMessageModule.receivingNonce(), 1_002);
    }

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
        bytes memory payload = abi.encode(address(leafGauge), amount);
        bytes memory message = abi.encode(Commands.NOTIFY, payload);

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
        bytes memory payload = abi.encode(address(leafGauge), amount);
        bytes memory message = abi.encode(Commands.NOTIFY_WITHOUT_CLAIM, payload);

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

    function testFuzz_WhenTheCommandIsInvalid(uint256 amount)
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It reverts with {InvalidCommand}
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(type(uint256).max, abi.encode(address(leafGauge), payload));

        vm.expectRevert(ILeafHLMessageModule.InvalidCommand.selector);
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
    }
}
