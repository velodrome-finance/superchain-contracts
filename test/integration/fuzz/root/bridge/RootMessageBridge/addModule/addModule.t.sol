// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract AddModuleIntegrationFuzzTest is RootMessageBridgeTest {
    function setUp() public virtual override {
        super.setUp();
        rootMessageBridge = new RootMessageBridge({
            _owner: users.owner,
            _xerc20: address(rootXVelo),
            _voter: address(mockVoter),
            _weth: address(weth)
        });
        rootMessageModule = new RootHLMessageModule({
            _bridge: address(rootMessageBridge),
            _mailbox: address(rootMailbox),
            _commands: defaultCommands,
            _gasLimits: defaultGasLimits
        });
    }

    function testFuzz_WhenTheCallerIsNotOwner(address _caller) external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.assume(_caller != users.owner);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        rootMessageBridge.addModule({_module: _caller});
    }

    modifier whenTheCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function testFuzz_WhenTheModuleIsAlreadyAddedToTheRegistry(address _module) external whenTheCallerIsOwner {
        // It reverts with {ModuleAlreadyAdded}
        rootMessageBridge.addModule({_module: _module});

        vm.expectRevert(ICrossChainRegistry.ModuleAlreadyAdded.selector);
        rootMessageBridge.addModule({_module: _module});
    }

    function testFuzz_WhenTheModuleIsNotAddedToTheRegistry(address _module) external whenTheCallerIsOwner {
        // It adds the module
        // It emits the event {ModuleAdded}
        vm.expectEmit(address(rootMessageBridge));
        emit ICrossChainRegistry.ModuleAdded({_module: _module});
        rootMessageBridge.addModule({_module: _module});

        address[] memory modules = rootMessageBridge.modules();
        assertEq(modules.length, 1);
        assertEq(modules[0], _module);
    }
}
