// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract HandleIntegrationFuzzTest is TokenBridgeTest {
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
        leafTokenBridge.handle({
            _origin: root,
            _sender: TypeCasts.addressToBytes32(_caller),
            _message: abi.encode(_caller, 1)
        });
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function test_WhenTheSenderIsNotBridge(address _sender) external whenTheCallerIsMailbox {
        // It should revert with NotBridge
        vm.assume(_sender != address(leafTokenBridge));
        sender = TypeCasts.addressToBytes32(_sender);
        vm.expectRevert(ITokenBridge.NotBridge.selector);
        leafTokenBridge.handle({_origin: root, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheSenderIsBridge() {
        sender = TypeCasts.addressToBytes32(address(leafTokenBridge));
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit(uint256 _mintingLimit, uint256 _amount)
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2);
        _amount = bound(_amount, _mintingLimit + 1, type(uint256).max);

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), _amount);

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        leafTokenBridge.handle{value: TOKEN_1 / 2}({_origin: root, _sender: sender, _message: _message});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(
        uint256 _mintingLimit,
        uint256 _amount
    ) external whenTheSenderIsBridge {
        // It should mint tokens to the destination bridge
        // It should emit {ReceivedMessage} event
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2);
        _amount = bound(_amount, WEEK, _mintingLimit);

        vm.prank(users.owner);
        leafXVelo.setLimits({_bridge: address(leafTokenBridge), _mintingLimit: _mintingLimit, _burningLimit: 0});

        vm.deal(address(leafMailbox), TOKEN_1 / 2);

        bytes memory _message = abi.encode(address(leafGauge), _amount);

        vm.prank(address(leafMailbox));
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: root,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        leafTokenBridge.handle{value: TOKEN_1 / 2}({_origin: root, _sender: sender, _message: _message});

        assertEq(leafXVelo.balanceOf(address(leafGauge)), _amount);
    }
}
