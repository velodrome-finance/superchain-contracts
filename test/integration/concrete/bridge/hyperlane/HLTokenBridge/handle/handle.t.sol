// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLTokenBridge.t.sol";

contract HandleIntegrationConcreteTest is HLTokenBridgeTest {
    uint32 origin;
    bytes32 sender = TypeCasts.addressToBytes32(users.charlie);

    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_WhenTheCallerIsNotMailbox() external {
        // It should revert with NotMailbox
        vm.prank(users.charlie);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafModule.handle({_origin: origin, _sender: sender, _message: abi.encode(users.charlie, 1)});
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function test_WhenTheOriginIsNotRoot() external whenTheCallerIsMailbox {
        // It should revert with NotRoot
        vm.expectRevert(IHLHandler.NotRoot.selector);
        leafModule.handle({_origin: origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheOriginIsRoot() {
        origin = 10;
        _;
    }

    function test_WhenTheSenderIsNotModule() external whenTheCallerIsMailbox whenTheOriginIsRoot {
        // It should revert with NotModule
        vm.expectRevert(IHLTokenBridge.NotModule.selector);
        leafModule.handle({_origin: origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheSenderIsModule() {
        sender = TypeCasts.addressToBytes32(address(leafModule));
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit()
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        uint256 amount = TOKEN_1;

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), amount);

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        leafModule.handle{value: TOKEN_1 / 2}({_origin: origin, _sender: sender, _message: _message});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit()
        external
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It should mint tokens to the destination contract
        // It should deposit the tokens into the gauge
        // It should emit {ReceivedMessage} event
        uint256 amount = TOKEN_1;

        vm.prank(users.owner);
        leafXVelo.setLimits({_bridge: address(leafBridge), _mintingLimit: amount, _burningLimit: 0});

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), amount);

        vm.prank(address(leafMailbox));
        vm.expectEmit(address(leafModule));
        emit IHLHandler.ReceivedMessage({
            _origin: origin,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        leafModule.handle{value: TOKEN_1 / 2}({_origin: origin, _sender: sender, _message: _message});

        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
    }
}
