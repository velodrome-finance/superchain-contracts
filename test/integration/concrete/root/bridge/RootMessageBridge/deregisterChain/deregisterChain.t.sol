// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract DeregisterChainIntegrationConcreteTest is RootMessageBridgeTest {
    function setUp() public virtual override {
        super.setUp();
        rootMessageBridge = new RootMessageBridge({
            _owner: users.owner,
            _xerc20: address(rootXVelo),
            _voter: address(mockVoter),
            _weth: address(weth)
        });
        rootMessageModule =
            new RootHLMessageModule({_bridge: address(rootMessageBridge), _mailbox: address(rootMailbox)});
    }

    function test_WhenTheCallerIsNotTheOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootMessageBridge.deregisterChain({_chainid: leaf});
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenTheChainIsNotRegistered() external whenTheCallerIsTheOwner {
        // It reverts with {ChainNotRegistered}
        uint256 chainid = block.chainid;

        vm.expectRevert(ICrossChainRegistry.ChainNotRegistered.selector);
        rootMessageBridge.deregisterChain({_chainid: chainid});
    }

    function test_WhenTheChainIsRegistered() external whenTheCallerIsTheOwner {
        // It removes the module from the chain id
        // It deregisters the chain id
        // It emits the {ChainRegistered} event
        uint256 chainid = 100;
        rootMessageBridge.addModule({_module: address(rootMessageModule)});
        rootMessageBridge.registerChain({_chainid: chainid, _module: address(rootMessageModule)});

        vm.expectEmit(address(rootMessageBridge));
        emit ICrossChainRegistry.ChainDeregistered({_chainid: chainid});
        rootMessageBridge.deregisterChain({_chainid: chainid});

        uint256[] memory chainids = rootMessageBridge.chainids();
        assertEq(chainids.length, 0);
        assertEq(rootMessageBridge.chains(chainid), address(0));
    }

    function testGas_deregisterChain() external whenTheCallerIsTheOwner {
        uint256 chainid = 100;
        rootMessageBridge.addModule({_module: address(rootMessageModule)});
        rootMessageBridge.registerChain({_chainid: chainid, _module: address(rootMessageModule)});

        rootMessageBridge.deregisterChain({_chainid: chainid});
        vm.snapshotGasLastCall("RootMessageBridge_deregisterChain");
    }
}
