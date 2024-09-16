// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract ReceiveIntegrationConcreteTest is RootHLMessageModuleTest {
    function test_WhenTheCallerIsNotWETH() external {
        // It reverts with {NotWETH}
        vm.deal({account: users.charlie, newBalance: 1 ether});

        vm.prank(users.charlie);
        vm.expectRevert(IRootMessageBridge.NotWETH.selector);
        (bool success,) = payable(rootMessageBridge).call{value: 1 ether}("");

        assertTrue(success);
    }

    function test_WhenTheCallerIsWETH() external {
        // It receives ETH
        vm.prank(address(weth));
        (bool success,) = payable(rootMessageBridge).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(address(rootMessageBridge).balance, 1 ether);
    }
}
