// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLUserTokenBridge.t.sol";

contract TransferIntegrationFuzzTest is HLUserTokenBridgeTest {
    function test_WhenTheCallerIsNotTheBridge(address _caller) external {
        // It should revert with NotBridge
        vm.assume(_caller != address(rootTokenBridge));

        vm.prank(_caller);
        vm.expectRevert(IHLTokenBridge.NotBridge.selector);
        rootTokenModule.transfer({_sender: _caller, _amount: 0, _chainid: leaf});
    }

    function test_WhenTheCallerIsTheBridge(uint256 _amount) external {
        // It dispatches a message to the destination mailbox
        // It emits a {SentMessage} event
        // It mints the amount of tokens to the caller on the destination chain
        uint256 amount = bound(_amount, WEEK, MAX_TOKENS);
        setLimits({_rootMintingLimit: amount, _leafMintingLimit: amount});
        uint256 ethAmount = TOKEN_1;
        vm.deal({account: address(rootTokenBridge), newBalance: ethAmount});

        vm.startPrank(address(rootTokenBridge));
        vm.expectEmit(address(rootTokenModule));
        emit IHLTokenBridge.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenModule)),
            _value: ethAmount,
            _message: string(abi.encode(address(rootGauge), amount))
        });
        rootTokenModule.transfer{value: ethAmount}({_sender: address(rootGauge), _amount: amount, _chainid: leaf});

        assertEq(address(rootTokenModule).balance, 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenModule));
        emit IHLHandler.ReceivedMessage({
            _origin: root,
            _sender: TypeCasts.addressToBytes32(address(leafTokenModule)),
            _value: 0,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
    }
}
