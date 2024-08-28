// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLMessageBridge.t.sol";

contract SendMessageIntegrationConcreteTest is HLMessageBridgeTest {
    function test_WhenTheCallerIsNotBridge(address _caller) external {
        // It reverts with NotBridge
        vm.assume(_caller != address(rootMessageBridge));
        vm.prank(_caller);
        vm.expectRevert(IHLMessageBridge.NotBridge.selector);
        rootMessageModule.sendMessage({_chainid: leaf, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    function test_WhenTheCallerIsBridge(uint256 ethAmount, uint256 amount) external {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));
        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        vm.prank(address(rootMessageBridge));
        vm.expectEmit(address(rootMessageModule));
        emit IHLMessageBridge.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(message)
        });
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        assertEq(address(rootMessageModule).balance, 0);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
    }
}
