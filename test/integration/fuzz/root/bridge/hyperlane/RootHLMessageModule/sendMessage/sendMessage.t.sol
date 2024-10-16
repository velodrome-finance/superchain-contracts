// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SendMessageIntegrationFuzzTest is RootHLMessageModuleTest {
    using stdStorage for StdStorage;
    using GasLimits for uint256;

    function testFuzz_WhenTheCallerIsNotBridge(address _caller) external {
        // It reverts with NotBridge
        vm.assume(_caller != address(rootMessageBridge));
        vm.prank(_caller);
        vm.expectRevert(IMessageSender.NotBridge.selector);
        rootMessageModule.sendMessage({_chainid: leaf, _message: abi.encodePacked(users.charlie, uint256(1))});
    }

    function testFuzz_WhenTheCallerIsBridge(uint256 amount) external {
        // It dispatches the message to the mailbox
        // It emits the {SentMessage} event
        // It calls receiveMessage on the recipient contract of the same address with the payload
        vm.selectFork({forkId: rootId});
        stdstore.target(address(rootMessageModule)).sig(rootMessageModule.sendingNonce.selector).with_key(leaf)
            .checked_write(1_000);
        vm.selectFork({forkId: leafId});
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        vm.selectFork({forkId: rootId});
        uint256 tokenId = 1;
        uint256 ethAmount = TOKEN_1;
        bytes memory message = abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId);
        bytes memory expectedMessage =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint256(1_000));

        vm.deal({account: address(rootMessageBridge), newBalance: ethAmount});

        vm.prank({msgSender: address(rootMessageBridge), txOrigin: users.alice});
        vm.expectEmit(address(rootMessageModule));
        emit IMessageSender.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootMessageModule)),
            _value: ethAmount,
            _message: string(expectedMessage),
            _metadata: string(
                StandardHookMetadata.formatMetadata({
                    _msgValue: ethAmount,
                    _gasLimit: Commands.DEPOSIT.gasLimit(),
                    _refundAddress: users.alice,
                    _customMetadata: ""
                })
            )
        });
        rootMessageModule.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        assertEq(rootMessageModule.sendingNonce(leaf), 1_001);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
        assertEq(leafMessageModule.receivingNonce(), 1_001);
    }
}