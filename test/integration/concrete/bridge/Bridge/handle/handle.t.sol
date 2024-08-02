// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract HandleIntegrationConcreteTest is BaseForkFixture {
    function test_WhenTheCallerIsNotMailbox() external {
        // It should revert with NotMailbox
        vm.prank(users.charlie);
        vm.expectRevert(IBridge.NotMailbox.selector);
        originBridge.handle({
            _origin: destination,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _message: abi.encode(users.alice, 1)
        });
    }

    modifier whenTheCallerIsMailbox() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit() external whenTheCallerIsMailbox {
        // It should revert with IXERC20_NotHighEnoughLimits
        uint256 amount = TOKEN_1;

        vm.prank(users.owner);
        originXVelo.setLimits({_bridge: address(destinationBridge), _mintingLimit: amount - 1, _burningLimit: 0});

        vm.deal(address(originMailbox), TOKEN_1);

        bytes memory _message = abi.encode(users.alice, amount);

        vm.prank(address(originMailbox));
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        originBridge.handle{value: TOKEN_1 / 2}({
            _origin: destination,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _message: _message
        });
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit() external whenTheCallerIsMailbox {
        // It should mint tokens to the destination contract
        uint256 amount = TOKEN_1;

        vm.prank(users.owner);
        originXVelo.setLimits({_bridge: address(destinationBridge), _mintingLimit: amount, _burningLimit: 0});

        vm.deal(address(originMailbox), TOKEN_1);

        bytes memory _message = abi.encode(users.alice, amount);

        vm.prank(address(originMailbox));
        vm.expectEmit(address(originBridge));
        emit IBridge.ReceivedMessage({
            _origin: destination,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        originBridge.handle{value: TOKEN_1 / 2}({
            _origin: destination,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _message: _message
        });

        assertEq(originXVelo.balanceOf(users.alice), amount);
    }
}
