// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SendMessageIntegrationFuzzTest is RootHLMessageModuleTest {
    using stdStorage for StdStorage;

    function testFuzz_WhenTheCallerIsNotBridge(address _caller) external {
        // It reverts with NotBridge
        vm.assume(_caller != address(rootMessageBridge));
        vm.prank(_caller);
        vm.expectRevert(IMessageSender.NotBridge.selector);
        rootMessageModule.sendMessage({_chainid: leaf, _message: abi.encode(users.charlie, abi.encode(1))});
    }

    function testFuzz_WhenTheCallerIsBridge(uint256 amount) external {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        vm.selectFork({forkId: rootId});
        stdstore.target(address(rootMessageModule)).sig("sendingNonce()").checked_write(1_000);
        vm.selectFork({forkId: leafId});
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        vm.selectFork({forkId: rootId});
        uint256 tokenId = 1;
        uint256 ethAmount = TOKEN_1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));
        bytes memory expectedMessage =
            abi.encode(Commands.DEPOSIT, abi.encode(1_000, abi.encode(address(leafGauge), payload)));

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        vm.prank(address(rootMessageBridge));
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(expectedMessage)
        });
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        assertEq(rootMessageModule.sendingNonce(), 1_001);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
        assertEq(leafMessageModule.receivingNonce(), 1_001);
    }
}
