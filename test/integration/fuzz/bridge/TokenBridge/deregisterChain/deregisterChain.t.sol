// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract DeregisterChainIntegrationFuzzTest is TokenBridgeTest {
    function testFuzz_WhenTheCallerIsNotTheOwner(address _caller) external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.assume(_caller != users.owner);
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        rootTokenBridge.deregisterChain({_chainid: 10});
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function testFuzz_WhenTheChainIsNotRegistered(uint256 _chainid) external whenTheCallerIsTheOwner {
        // It reverts with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        rootTokenBridge.deregisterChain({_chainid: _chainid});
    }

    function testFuzz_WhenTheChainIsRegistered(uint256 _chainid) external whenTheCallerIsTheOwner {
        // It deregisters the chain id
        // It emits the {ChainRegistered} event
        vm.assume(_chainid != block.chainid);
        rootTokenBridge.registerChain({_chainid: _chainid});

        vm.expectEmit(address(rootTokenBridge));
        emit IChainRegistry.ChainDeregistered({_chainid: _chainid});
        rootTokenBridge.deregisterChain({_chainid: _chainid});

        uint256[] memory chainids = rootTokenBridge.chainids();
        assertEq(chainids.length, 0);
    }
}