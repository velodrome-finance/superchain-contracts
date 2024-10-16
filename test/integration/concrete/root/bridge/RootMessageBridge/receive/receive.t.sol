// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract ReceiveIntegrationConcreteTest is RootMessageBridgeTest {
    function test_InitialState() public override {
        vm.selectFork({forkId: rootId});
        assertEq(rootMessageBridge.owner(), users.owner);
        assertEq(rootMessageBridge.xerc20(), address(rootXVelo));
        assertEq(rootMessageBridge.voter(), address(mockVoter));
        assertEq(rootMessageBridge.factoryRegistry(), address(mockFactoryRegistry));
        assertEq(rootMessageBridge.weth(), address(weth));
        // chain was deregistered in set up, but module was added in base fork fixture
        uint256[] memory chainids = rootMessageBridge.chainids();
        assertEq(chainids.length, 1);
        address[] memory modules = rootMessageBridge.modules();
        assertEq(modules.length, 1);
        assertEq(modules[0], address(rootMessageModule));
    }

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
