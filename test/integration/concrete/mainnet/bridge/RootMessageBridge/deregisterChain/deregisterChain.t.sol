// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract DeregisterChainIntegrationConcreteTest is RootMessageBridgeTest {
    function test_WhenTheCallerIsNotTheOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        newRootMessageBridge.deregisterChain({_chainid: 10});
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenTheChainIsNotRegistered() external whenTheCallerIsTheOwner {
        // It reverts with {NotRegistered}
        uint256 chainid = block.chainid;

        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        newRootMessageBridge.deregisterChain({_chainid: chainid});
    }

    function test_WhenTheChainIsRegistered() external whenTheCallerIsTheOwner {
        // It deregisters the chain id
        // It emits the {ChainRegistered} event
        uint256 chainid = 100;
        newRootMessageBridge.registerChain({_chainid: chainid});

        vm.expectEmit(address(newRootMessageBridge));
        emit IChainRegistry.ChainDeregistered({_chainid: chainid});
        newRootMessageBridge.deregisterChain({_chainid: chainid});

        uint256[] memory chainids = newRootMessageBridge.chainids();
        assertEq(chainids.length, 0);
    }
}
