// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLTokenBridge.t.sol";

contract HandleIntegrationFuzzTest is HLTokenBridgeTest {
    uint32 origin;
    bytes32 sender;

    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_WhenTheCallerIsNotMailbox(address _caller) external {
        // It should revert with NotMailbox
        vm.assume(_caller != address(leafMailbox));

        vm.prank(_caller);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafModule.handle({_origin: origin, _sender: sender, _message: abi.encode(_caller, 1)});
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function test_WhenTheOriginIsNotRoot(uint32 _origin) external whenTheCallerIsMailbox {
        // It should revert with NotRoot
        vm.assume(_origin != root);
        vm.expectRevert(IHLHandler.NotRoot.selector);
        leafModule.handle({_origin: _origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheOriginIsRoot() {
        origin = 10;
        _;
    }

    function test_WhenTheSenderIsNotModule(address _sender) external whenTheCallerIsMailbox whenTheOriginIsRoot {
        // It should revert with NotModule
        vm.assume(_sender != address(leafModule));
        sender = TypeCasts.addressToBytes32(_sender);
        vm.expectRevert(IHLMessageBridge.NotModule.selector);
        leafModule.handle({_origin: origin, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheSenderIsModule() {
        sender = TypeCasts.addressToBytes32(address(leafModule));
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit(uint256 _mintingLimit, uint256 _amount)
        external
        whenTheCallerIsMailbox
        whenTheOriginIsRoot
        whenTheSenderIsModule
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2);
        _amount = bound(_amount, _mintingLimit + 1, type(uint256).max);

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), _amount);

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        leafModule.handle{value: TOKEN_1 / 2}({
            _origin: root,
            _sender: TypeCasts.addressToBytes32(address(leafModule)),
            _message: _message
        });
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(
        uint256 _mintingLimit,
        uint256 _amount
    ) external whenTheOriginIsRoot whenTheSenderIsModule {
        // It should mint tokens to the destination module
        // It should deposit the tokens into the gauge
        // It should emit {ReceivedMessage} event
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2);
        _amount = bound(_amount, WEEK, _mintingLimit);

        vm.prank(users.owner);
        leafXVelo.setLimits({_bridge: address(leafBridge), _mintingLimit: _mintingLimit, _burningLimit: 0});

        vm.deal(address(leafMailbox), TOKEN_1 / 2);

        bytes memory _message = abi.encode(address(leafGauge), _amount);

        vm.prank(address(leafMailbox));
        vm.expectEmit(address(leafModule));
        emit IHLHandler.ReceivedMessage({
            _origin: origin,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        leafModule.handle{value: TOKEN_1 / 2}({_origin: origin, _sender: sender, _message: _message});

        assertEq(leafXVelo.balanceOf(address(leafGauge)), _amount);
    }
}
