// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLUserTokenBridge.t.sol";

contract HandleIntegrationConcreteTest is HLUserTokenBridgeTest {
    bytes32 sender = TypeCasts.addressToBytes32(users.charlie);

    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_WhenTheCallerIsNotMailbox() external {
        // It should revert with NotMailbox
        vm.prank(users.charlie);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafTokenModule.handle({_origin: root, _sender: sender, _message: abi.encode(users.charlie, 1)});
    }

    modifier whenTheCallerIsMailbox() {
        vm.startPrank(address(leafMailbox));
        _;
    }

    function test_WhenTheSenderIsNotModule() external whenTheCallerIsMailbox {
        // It should revert with NotModule
        vm.expectRevert(IHLTokenBridge.NotModule.selector);
        leafTokenModule.handle({_origin: root, _sender: sender, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    modifier whenTheSenderIsModule() {
        sender = TypeCasts.addressToBytes32(address(leafTokenModule));
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsModule
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        uint256 amount = TOKEN_1;

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), amount);

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        leafTokenModule.handle{value: TOKEN_1 / 2}({_origin: root, _sender: sender, _message: _message});
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit() external whenTheSenderIsModule {
        // It should mint tokens to the destination contract
        // It should emit {ReceivedMessage} event
        uint256 amount = TOKEN_1;

        vm.prank(users.owner);
        leafXVelo.setLimits({_bridge: address(leafTokenBridge), _mintingLimit: amount, _burningLimit: 0});

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), amount);

        vm.prank(address(leafMailbox));
        vm.expectEmit(address(leafTokenModule));
        emit IHLHandler.ReceivedMessage({
            _origin: root,
            _sender: sender,
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        leafTokenModule.handle{value: TOKEN_1 / 2}({_origin: root, _sender: sender, _message: _message});

        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
    }
}
