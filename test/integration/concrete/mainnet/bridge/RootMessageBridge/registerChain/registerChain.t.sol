// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract RegisterChainIntegrationConcreteTest is RootMessageBridgeTest {
    function test_WhenTheCallerIsNotTheOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        newRootMessageBridge.registerChain({_chainid: 10});
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenTheChainIsTheCurrentChain() external whenTheCallerIsTheOwner {
        // It reverts with {InvalidChain}
        uint256 chainid = block.chainid;

        vm.expectRevert(IChainRegistry.InvalidChain.selector);
        newRootMessageBridge.registerChain({_chainid: chainid});
    }

    modifier whenTheChainIsNotTheCurrentChain() {
        _;
    }

    function test_WhenTheChainIsAlreadyRegistered() external whenTheCallerIsTheOwner whenTheChainIsNotTheCurrentChain {
        // It reverts with {AlreadyRegistered}
        uint256 chainid = 100;
        newRootMessageBridge.registerChain({_chainid: chainid});

        vm.expectRevert(IChainRegistry.AlreadyRegistered.selector);
        newRootMessageBridge.registerChain({_chainid: chainid});
    }

    function test_WhenTheChainIsNotAlreadyRegistered()
        external
        whenTheCallerIsTheOwner
        whenTheChainIsNotTheCurrentChain
    {
        // It registers the chain id
        // It emits the {ChainRegistered} event
        uint256 chainid = 100;

        vm.expectEmit(address(newRootMessageBridge));
        emit IChainRegistry.ChainRegistered({_chainid: chainid});
        newRootMessageBridge.registerChain({_chainid: chainid});

        uint256[] memory chainids = newRootMessageBridge.chainids();
        assertEq(chainids.length, 1);
        assertEq(chainids[0], chainid);
    }
}
