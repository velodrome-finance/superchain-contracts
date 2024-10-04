// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract SetModuleIntegrationConcreteTest is RootMessageBridgeTest {
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

    function test_WhenTheCallerIsNotOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootMessageBridge.setModule({_chainid: 1, _module: users.charlie});
    }

    modifier whenTheCallerIsOwner() {
        _;
    }

    function test_WhenTheModuleIsNotAddedToTheRegistry() external whenTheCallerIsOwner {
        // It reverts with {ModuleNotAdded}
        vm.startPrank(users.owner);
        vm.expectRevert(ICrossChainRegistry.ModuleNotAdded.selector);
        rootMessageBridge.setModule({_chainid: 1, _module: users.owner});
    }

    modifier whenTheModuleIsAddedToTheRegistry() {
        vm.prank(users.owner);
        rootMessageBridge.addModule({_module: address(rootMessageModule)});
        _;
    }

    function test_WhenTheChainIsNotRegistered() external whenTheCallerIsOwner whenTheModuleIsAddedToTheRegistry {
        // It reverts with {ChainNotRegistered}
        vm.startPrank(users.owner);
        vm.expectRevert(ICrossChainRegistry.ChainNotRegistered.selector);
        rootMessageBridge.setModule({_chainid: 1, _module: address(rootMessageModule)});
    }

    function test_WhenTheChainIsRegistered() external whenTheCallerIsOwner whenTheModuleIsAddedToTheRegistry {
        // It sets the module
        // It emits the event {ModuleSet}
        vm.startPrank(users.owner);
        rootMessageBridge.addModule({_module: address(1)});
        rootMessageBridge.registerChain({_chainid: 1, _module: address(1)});

        vm.expectEmit(address(rootMessageBridge));
        emit ICrossChainRegistry.ModuleSet({_chainid: 1, _module: address(rootMessageModule)});
        rootMessageBridge.setModule({_chainid: 1, _module: address(rootMessageModule)});

        uint256[] memory chains = rootMessageBridge.chainids();
        assertEq(chains.length, 1);
        assertEq(chains[0], 1);
        address[] memory modules = rootMessageBridge.modules();
        assertEq(modules.length, 2);
        assertEq(modules[0], address(rootMessageModule));
        assertEq(modules[1], address(1));
        assertEq(rootMessageBridge.chains(1), address(rootMessageModule));
    }

    function testGas_WhenTheChainIsRegistered() external whenTheCallerIsOwner whenTheModuleIsAddedToTheRegistry {
        vm.startPrank(users.owner);
        rootMessageBridge.addModule({_module: address(1)});
        rootMessageBridge.registerChain({_chainid: 1, _module: address(1)});

        rootMessageBridge.setModule({_chainid: 1, _module: address(rootMessageModule)});
        snapLastCall("RootMessageBridge_setModule");
    }
}
