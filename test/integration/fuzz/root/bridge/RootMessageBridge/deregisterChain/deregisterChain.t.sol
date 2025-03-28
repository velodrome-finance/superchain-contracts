// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract DeregisterChainIntegrationFuzzTest is RootMessageBridgeTest {
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

    function testFuzz_WhenTheCallerIsNotTheOwner(address _caller) external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.assume(_caller != users.owner);
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        rootMessageBridge.deregisterChain({_chainid: leaf});
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function testFuzz_WhenTheChainIsNotRegistered(uint256 _chainid) external whenTheCallerIsTheOwner {
        // It reverts with {ChainNotRegistered}
        vm.expectRevert(ICrossChainRegistry.ChainNotRegistered.selector);
        rootMessageBridge.deregisterChain({_chainid: _chainid});
    }

    function testFuzz_WhenTheChainIsRegistered(uint256 _chainid) external whenTheCallerIsTheOwner {
        // It removes the module from the chain id
        // It deregisters the chain id
        // It emits the {ChainRegistered} event
        vm.assume(_chainid != 10);
        rootMessageBridge.addModule({_module: address(rootMessageModule)});
        rootMessageBridge.registerChain({_chainid: _chainid, _module: address(rootMessageModule)});

        vm.expectEmit(address(rootMessageBridge));
        emit ICrossChainRegistry.ChainDeregistered({_chainid: _chainid});
        rootMessageBridge.deregisterChain({_chainid: _chainid});

        uint256[] memory chainids = rootMessageBridge.chainids();
        assertEq(chainids.length, 0);
        assertEq(rootMessageBridge.chains(_chainid), address(0));
    }
}
