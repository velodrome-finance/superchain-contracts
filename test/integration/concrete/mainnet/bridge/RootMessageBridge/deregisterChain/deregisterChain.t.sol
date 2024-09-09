// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract DeregisterChainIntegrationConcreteTest is RootMessageBridgeTest {
    function setUp() public override {
        super.setUp();

        // deploy fresh instance
        rootMessageBridge = RootMessageBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(RootMessageBridge).creationCode,
                    abi.encode(
                        users.owner, // message bridge owner
                        address(rootXVelo), // xerc20 address
                        address(mockVoter), // mock root voter
                        address(rootMessageModule), // message module
                        address(rootGaugeFactory) // root gauge factory
                    )
                )
            })
        );
    }

    function test_WhenTheCallerIsNotTheOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootMessageBridge.deregisterChain({_chainid: 10});
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenTheChainIsNotRegistered() external whenTheCallerIsTheOwner {
        // It reverts with {NotRegistered}
        uint256 chainid = block.chainid;

        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        rootMessageBridge.deregisterChain({_chainid: chainid});
    }

    function test_WhenTheChainIsRegistered() external whenTheCallerIsTheOwner {
        // It deregisters the chain id
        // It emits the {ChainRegistered} event
        uint256 chainid = 100;
        rootMessageBridge.registerChain({_chainid: chainid});

        vm.expectEmit(address(rootMessageBridge));
        emit IChainRegistry.ChainDeregistered({_chainid: chainid});
        rootMessageBridge.deregisterChain({_chainid: chainid});

        uint256[] memory chainids = rootMessageBridge.chainids();
        assertEq(chainids.length, 0);
    }
}
