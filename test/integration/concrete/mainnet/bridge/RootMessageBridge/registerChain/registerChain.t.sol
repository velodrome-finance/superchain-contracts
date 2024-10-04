// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract RegisterChainIntegrationConcreteTest is RootMessageBridgeTest {
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
        rootMessageBridge.registerChain({_chainid: 10, _module: users.charlie});
    }

    modifier whenTheCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenTheChainIdIs10() external whenTheCallerIsOwner {
        // It reverts with {InvalidChainId}
        vm.expectRevert(ICrossChainRegistry.InvalidChainId.selector);
        rootMessageBridge.registerChain({_chainid: 10, _module: users.charlie});
    }

    modifier whenTheChainIdIsNot10() {
        _;
    }

    function test_WhenTheModuleIsNotAddedToTheRegistry() external whenTheCallerIsOwner whenTheChainIdIsNot10 {
        // It reverts with {ModuleNotAdded}
        vm.expectRevert(ICrossChainRegistry.ModuleNotAdded.selector);
        rootMessageBridge.registerChain({_chainid: leaf, _module: users.owner});
    }

    modifier whenTheModuleIsAddedToTheRegistry() {
        rootMessageBridge.addModule(address(rootMessageModule));
        _;
    }

    function test_WhenTheChainIsAlreadyRegistered()
        external
        whenTheCallerIsOwner
        whenTheChainIdIsNot10
        whenTheModuleIsAddedToTheRegistry
    {
        // It reverts with {ChainAlreadyAdded}
        rootMessageBridge.registerChain({_chainid: leaf, _module: address(rootMessageModule)});

        vm.expectRevert(ICrossChainRegistry.ChainAlreadyAdded.selector);
        rootMessageBridge.registerChain({_chainid: leaf, _module: address(rootMessageModule)});
    }

    function test_WhenTheChainIsNotRegistered()
        external
        whenTheCallerIsOwner
        whenTheChainIdIsNot10
        whenTheModuleIsAddedToTheRegistry
    {
        // It sets the module for the chain id
        // It adds the chain ids to the registry
        // It emits the event {ChainRegistered}
        vm.expectEmit(address(rootMessageBridge));
        emit ICrossChainRegistry.ChainRegistered({_chainid: leaf, _module: address(rootMessageModule)});
        rootMessageBridge.registerChain({_chainid: leaf, _module: address(rootMessageModule)});

        uint256[] memory chainids = rootMessageBridge.chainids();
        assertEq(chainids.length, 1);
        assertEq(chainids[0], leaf);
        assertEq(rootMessageBridge.chains(leaf), address(rootMessageModule));
    }

    function testGas_WhenTheChainIsNotRegistered()
        external
        whenTheCallerIsOwner
        whenTheChainIdIsNot10
        whenTheModuleIsAddedToTheRegistry
    {
        rootMessageBridge.registerChain({_chainid: leaf, _module: address(rootMessageModule)});
        snapLastCall("RootMessageBridge_registerChain");
    }
}
