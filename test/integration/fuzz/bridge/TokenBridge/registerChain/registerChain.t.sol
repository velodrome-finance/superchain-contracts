// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract RegisterChainIntegrationFuzzTest is TokenBridgeTest {
    function testFuzz_WhenTheCallerIsNotTheOwner(address _caller) external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.assume(_caller != users.owner);
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        rootTokenBridge.registerChain({_chainid: 10});
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function testFuzz_WhenTheChainIsTheCurrentChain() external whenTheCallerIsTheOwner {}

    modifier whenTheChainIsNotTheCurrentChain() {
        _;
    }

    function testFuzz_WhenTheChainIsAlreadyRegistered(uint256 _chainid)
        external
        whenTheCallerIsTheOwner
        whenTheChainIsNotTheCurrentChain
    {
        // It reverts with {AlreadyRegistered}
        vm.assume(_chainid != block.chainid);
        rootTokenBridge.registerChain({_chainid: _chainid});

        vm.expectRevert(IChainRegistry.AlreadyRegistered.selector);
        rootTokenBridge.registerChain({_chainid: _chainid});
    }

    function testFuzz_WhenTheChainIsNotAlreadyRegistered(uint256 _chainid)
        external
        whenTheCallerIsTheOwner
        whenTheChainIsNotTheCurrentChain
    {
        // It registers the chain id
        // It emits the {ChainRegistered} event
        vm.assume(_chainid != block.chainid);

        vm.expectEmit(address(rootTokenBridge));
        emit IChainRegistry.ChainRegistered({_chainid: _chainid});
        rootTokenBridge.registerChain({_chainid: _chainid});

        uint256[] memory chainids = rootTokenBridge.chainids();
        assertEq(chainids.length, 1);
        assertEq(chainids[0], _chainid);
    }
}
