// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract SetModuleIntegrationFuzzTest is RootMessageBridgeTest {
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
            _paymasterVault: address(rootModuleVault),
            _commands: defaultCommands,
            _gasLimits: defaultGasLimits
        });
    }

    function testFuzz_WhenTheCallerIsNotOwner(address _caller) external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.assume(_caller != users.owner);
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        rootMessageBridge.setModule({_chainid: 1, _module: _caller});
    }

    modifier whenTheCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function testFuzz_WhenTheModuleIsNotAddedToTheRegistry(address _module) external whenTheCallerIsOwner {
        // It reverts with {ModuleNotAdded}
        vm.expectRevert(ICrossChainRegistry.ModuleNotAdded.selector);
        rootMessageBridge.setModule({_chainid: 1, _module: _module});
    }

    modifier whenTheModuleIsAddedToTheRegistry(address _module) {
        vm.assume(_module != address(1));
        rootMessageBridge.addModule({_module: _module});
        _;
    }

    function testFuzz_WhenTheChainIsNotRegistered(uint256 _chainid, address _module)
        external
        whenTheCallerIsOwner
        whenTheModuleIsAddedToTheRegistry(_module)
    {
        // It reverts with {ChainNotRegistered}
        vm.expectRevert(ICrossChainRegistry.ChainNotRegistered.selector);
        rootMessageBridge.setModule({_chainid: _chainid, _module: _module});
    }

    function testFuzz_WhenTheChainIsRegistered(uint256 _chainid, address _module)
        external
        whenTheCallerIsOwner
        whenTheModuleIsAddedToTheRegistry(_module)
    {
        // It sets the module
        // It emits the event {ModuleSet}
        vm.assume(_chainid != 10);
        vm.startPrank(users.owner);
        rootMessageBridge.addModule({_module: address(1)});
        rootMessageBridge.registerChain({_chainid: _chainid, _module: address(1)});

        vm.expectEmit(address(rootMessageBridge));
        emit ICrossChainRegistry.ModuleSet({_chainid: _chainid, _module: _module});
        rootMessageBridge.setModule({_chainid: _chainid, _module: _module});

        uint256[] memory chains = rootMessageBridge.chainids();
        assertEq(chains.length, 1);
        assertEq(chains[0], _chainid);
        address[] memory modules = rootMessageBridge.modules();
        assertEq(modules.length, 2);
        assertEq(modules[0], _module);
        assertEq(modules[1], address(1));
        assertEq(rootMessageBridge.chains(_chainid), _module);
    }
}
