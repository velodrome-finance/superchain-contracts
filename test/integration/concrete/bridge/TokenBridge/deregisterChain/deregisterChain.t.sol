// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract DeregisterChainIntegrationConcreteTest is TokenBridgeTest {
    function test_WhenTheCallerIsNotTheOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        leafTokenBridge.deregisterChain({_chainid: 10});
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenTheChainIsNotRegistered() external whenTheCallerIsTheOwner {
        // It reverts with {NotRegistered}
        uint256 chainid = block.chainid;

        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        leafTokenBridge.deregisterChain({_chainid: chainid});
    }

    function test_WhenTheChainIsRegistered() external whenTheCallerIsTheOwner {
        // It deregisters the chain id
        // It emits the {ChainRegistered} event
        uint256 chainid = 100;
        leafTokenBridge.registerChain({_chainid: chainid});

        vm.expectEmit(address(leafTokenBridge));
        emit IChainRegistry.ChainDeregistered({_chainid: chainid});
        leafTokenBridge.deregisterChain({_chainid: chainid});

        uint256[] memory chainids = leafTokenBridge.chainids();
        assertEq(chainids.length, 0);
    }
}
