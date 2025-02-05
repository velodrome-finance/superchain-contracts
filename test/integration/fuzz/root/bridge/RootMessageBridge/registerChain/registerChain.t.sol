// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract RegisterChainIntegrationFuzzTest is RootMessageBridgeTest {
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
        rootMessageBridge.registerChain({_chainid: 10, _module: _caller});
    }

    modifier whenTheCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function testFuzz_WhenTheChainIdIs10() external whenTheCallerIsOwner {}

    modifier whenTheChainIdIsNot10(uint256 _chainid) {
        vm.assume(_chainid != 10);
        _;
    }

    function testFuzz_WhenTheModuleIsNotAddedToTheRegistry(uint256 _chainid, address _module)
        external
        whenTheCallerIsOwner
        whenTheChainIdIsNot10(_chainid)
    {
        // It reverts with {ModuleNotAdded}
        vm.expectRevert(ICrossChainRegistry.ModuleNotAdded.selector);
        rootMessageBridge.registerChain({_chainid: _chainid, _module: _module});
    }

    modifier whenTheModuleIsAddedToTheRegistry(address _module) {
        rootMessageBridge.addModule(_module);
        _;
    }

    function testFuzz_WhenTheChainIsAlreadyRegistered(uint256 _chainid, address _module)
        external
        whenTheCallerIsOwner
        whenTheChainIdIsNot10(_chainid)
        whenTheModuleIsAddedToTheRegistry(_module)
    {
        // It reverts with {ChainAlreadyAdded}
        rootMessageBridge.registerChain({_chainid: _chainid, _module: _module});

        vm.expectRevert(ICrossChainRegistry.ChainAlreadyAdded.selector);
        rootMessageBridge.registerChain({_chainid: _chainid, _module: _module});
    }

    function testFuzz_WhenTheChainIsNotRegistered(uint256 _chainid, address _module)
        external
        whenTheCallerIsOwner
        whenTheChainIdIsNot10(_chainid)
        whenTheModuleIsAddedToTheRegistry(_module)
    {
        // It sets the module for the chain id
        // It adds the chain ids to the registry
        // It emits the event {ChainRegistered}
        vm.expectEmit(address(rootMessageBridge));
        emit ICrossChainRegistry.ChainRegistered({_chainid: _chainid, _module: _module});
        rootMessageBridge.registerChain({_chainid: _chainid, _module: _module});

        uint256[] memory chainids = rootMessageBridge.chainids();
        assertEq(chainids.length, 1);
        assertEq(chainids[0], _chainid);
        assertEq(rootMessageBridge.chains(_chainid), _module);
    }
}
