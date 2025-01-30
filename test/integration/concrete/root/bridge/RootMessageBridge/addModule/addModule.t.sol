// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract AddModuleIntegrationConcreteTest is RootMessageBridgeTest {
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

    function test_WhenTheCallerIsNotOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootMessageBridge.addModule({_module: users.charlie});
    }

    modifier whenTheCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenTheModuleIsAlreadyAddedToTheRegistry() external whenTheCallerIsOwner {
        // It reverts with {ModuleAlreadyAdded}
        rootMessageBridge.addModule({_module: address(rootMessageModule)});

        vm.expectRevert(ICrossChainRegistry.ModuleAlreadyAdded.selector);
        rootMessageBridge.addModule({_module: address(rootMessageModule)});
    }

    function test_WhenTheModuleIsNotAddedToTheRegistry() external whenTheCallerIsOwner {
        // It adds the module
        // It emits the event {ModuleAdded}
        vm.expectEmit(address(rootMessageBridge));
        emit ICrossChainRegistry.ModuleAdded({_module: address(rootMessageModule)});
        rootMessageBridge.addModule({_module: address(rootMessageModule)});

        address[] memory modules = rootMessageBridge.modules();
        assertEq(modules.length, 1);
        assertEq(modules[0], address(rootMessageModule));
    }

    function testGas_addModule() external whenTheCallerIsOwner {
        rootMessageBridge.addModule({_module: address(rootMessageModule)});
        vm.snapshotGasLastCall("RootMessageBridge_addModule");
    }
}
