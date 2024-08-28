// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLTokenBridge.t.sol";

contract TransferIntegrationFuzzTest is HLTokenBridgeTest {
    function test_WhenTheCallerIsNotTheBridge(address _caller) external {
        // It should revert with NotBridge
        vm.assume(_caller != address(rootBridge));

        vm.prank(_caller);
        vm.expectRevert(IHLTokenBridge.NotBridge.selector);
        rootModule.transfer({_sender: _caller, _amount: 0, _chainid: leaf});
    }

    function test_WhenTheCallerIsTheBridge(uint256 _amount) external {
        // It dispatches a message to the destination mailbox
        // It emits a {SentMessage} event
        // It mints the amount of tokens to the caller on the destination chain
        uint256 amount = bound(_amount, WEEK, MAX_TOKENS);
        uint256 ethAmount = TOKEN_1;
        vm.deal({account: address(rootBridge), newBalance: ethAmount});
        setLimits({_rootMintingLimit: amount, _leafMintingLimit: amount});

        vm.startPrank(address(rootBridge));
        vm.expectEmit(address(rootModule));
        emit IHLTokenBridge.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootModule)),
            _value: ethAmount,
            _message: string(abi.encode(address(rootGauge), amount))
        });
        rootModule.transfer{value: ethAmount}({_sender: address(rootGauge), _amount: amount, _chainid: leaf});

        assertEq(address(rootModule).balance, 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafModule));
        emit IHLHandler.ReceivedMessage({
            _origin: root,
            _sender: TypeCasts.addressToBytes32(address(leafModule)),
            _value: 0,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
    }
}
