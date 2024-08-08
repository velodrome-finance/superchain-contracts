// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLTokenBridge.t.sol";

contract HandleIntegrationConcreteTest is HLTokenBridgeTest {
    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_WhenTheCallerIsNotMailbox() external {
        // It should revert with NotMailbox
        vm.prank(users.charlie);
        vm.expectRevert(IHLTokenBridge.NotMailbox.selector);
        leafModule.handle({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(users.charlie),
            _message: abi.encode(users.charlie, 1)
        });
    }

    modifier whenTheCallerIsMailbox() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit() external whenTheCallerIsMailbox {
        // It should revert with IXERC20_NotHighEnoughLimits
        uint256 amount = TOKEN_1;

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), amount);

        vm.prank(address(leafMailbox));
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        leafModule.handle{value: TOKEN_1 / 2}({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _message: _message
        });
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit() external whenTheCallerIsMailbox {
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
        emit IHLTokenBridge.ReceivedMessage({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        leafModule.handle{value: TOKEN_1 / 2}({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _message: _message
        });

        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
    }
}
