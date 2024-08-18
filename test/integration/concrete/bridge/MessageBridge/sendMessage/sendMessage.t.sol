// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../MessageBridge.t.sol";

contract SendMessageIntegrationConcreteTest is MessageBridgeTest {
    function test_WhenTheCallerIsAnyone() external {
        // It dispatches the message to the message module
        uint256 ethAmount = TOKEN_1;
        vm.deal({account: users.alice, newBalance: ethAmount});

        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(address(leafGauge), payload));

        vm.prank(users.alice);
        rootMessageBridge.sendMessage{value: ethAmount}({_chainid: leaf, _message: message});

        assertEq(address(rootMessageModule).balance, 0);

        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafFVR.totalSupply(), amount);
        assertEq(leafFVR.balanceOf(tokenId), amount);
        assertEq(leafIVR.totalSupply(), amount);
        assertEq(leafIVR.balanceOf(tokenId), amount);
    }
}
